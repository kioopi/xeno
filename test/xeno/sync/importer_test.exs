defmodule Xeno.Sync.ImporterTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Sync.Importer

  describe "parse_markdown/1" do
    test "extracts text content from markdown string" do
      markdown = "# Hello World\n\nThis is some content."

      assert {:ok, text} = Importer.parse_markdown(markdown)
      assert text == "# Hello World\n\nThis is some content."
    end

    test "handles empty content" do
      assert {:ok, text} = Importer.parse_markdown("")
      assert text == ""
    end

    test "handles nil content" do
      assert {:ok, text} = Importer.parse_markdown(nil)
      assert text == ""
    end

    test "preserves whitespace and formatting" do
      markdown = "Line 1\n\n  Indented line\n\nLine 3"

      assert {:ok, text} = Importer.parse_markdown(markdown)
      assert text == markdown
    end
  end

  describe "parse_metadata/1" do
    test "decodes valid JSON string" do
      json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Test Note",
        "version": 1
      }
      """

      assert {:ok, metadata} = Importer.parse_metadata(json)
      assert metadata["id"] == "550e8400-e29b-41d4-a716-446655440000"
      assert metadata["name"] == "Test Note"
      assert metadata["version"] == 1
    end

    test "returns error for invalid JSON" do
      invalid_json = "{invalid json"

      assert {:error, %Jason.DecodeError{}} = Importer.parse_metadata(invalid_json)
    end

    test "handles JSON with special characters" do
      json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Note with \\"quotes\\" and \\n newlines",
        "version": 1
      }
      """

      assert {:ok, metadata} = Importer.parse_metadata(json)
      assert metadata["name"] == "Note with \"quotes\" and \n newlines"
    end

    test "handles empty JSON object" do
      assert {:ok, metadata} = Importer.parse_metadata("{}")
      assert metadata == %{}
    end
  end

  describe "validate_metadata/1" do
    test "validates metadata with required fields" do
      metadata = %{
        "id" => "550e8400-e29b-41d4-a716-446655440000",
        "version" => 1
      }

      assert :ok = Importer.validate_metadata(metadata)
    end

    test "returns error when id field is missing" do
      metadata = %{"version" => 1}

      assert {:error, "Missing required field: id"} = Importer.validate_metadata(metadata)
    end

    test "returns error when version field is missing" do
      metadata = %{"id" => "550e8400-e29b-41d4-a716-446655440000"}

      assert {:error, "Missing required field: version"} = Importer.validate_metadata(metadata)
    end

    test "returns error for invalid UUID format" do
      metadata = %{
        "id" => "not-a-uuid",
        "version" => 1
      }

      assert {:error, "Invalid UUID format for id"} = Importer.validate_metadata(metadata)
    end

    test "allows optional fields" do
      metadata = %{
        "id" => "550e8400-e29b-41d4-a716-446655440000",
        "version" => 1,
        "name" => "Optional Name",
        "tags" => ["tag1", "tag2"],
        "data" => %{"custom" => "field"}
      }

      assert :ok = Importer.validate_metadata(metadata)
    end
  end

  describe "import_change/1" do
    setup do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "testdir"))

      note =
        generate(
          note(
            name: "Original Note",
            filename: "original-note",
            text: "Original content",
            data: %{"key" => "original"},
            tags: ["original"],
            note_type_id: note_type.id,
            directory_id: directory.id
          )
        )

      %{note: note, note_type: note_type, directory: directory}
    end

    test "imports change with updated markdown content", %{note: note} do
      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => "# Updated Content\n\nThis has been edited.",
        "metadata" => %{
          "id" => note.id,
          "version" => note.version
        }
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "# Updated Content\n\nThis has been edited."
      assert updated_note.version == note.version + 1
    end

    test "imports change with updated metadata fields", %{note: note} do
      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => note.text,
        "metadata" => %{
          "id" => note.id,
          "version" => note.version,
          "name" => "Updated Name",
          "tags" => ["updated", "tags"],
          "data" => %{"key" => "updated"}
        }
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.name == "Updated Name"
      assert Enum.sort(updated_note.tags) == ["tags", "updated"]
      assert updated_note.data == %{"key" => "updated"}
    end

    test "returns error for version conflict (stale record)", %{note: note} do
      Xeno.Content.Note.update!(note, %{text: "Concurrent edit"})

      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => "My edit",
        "metadata" => %{
          "id" => note.id,
          "version" => note.version
        }
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.class == :invalid
    end

    test "returns error for missing note", %{note: _note} do
      non_existent_id = Ash.UUID.generate()

      change_attrs = %{
        "note_id" => non_existent_id,
        "markdown_content" => "Content",
        "metadata" => %{
          "id" => non_existent_id,
          "version" => 1
        }
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.class == :invalid
    end

    test "returns error for invalid metadata", %{note: note} do
      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => "Content",
        "metadata" => %{
          "version" => note.version
        }
      }

      assert {:error, "Missing required field: id"} = Importer.import_change(change_attrs)
    end

    test "preserves unchanged fields", %{note: note} do
      original_data = note.data
      original_tags = note.tags

      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => "Only text changed",
        "metadata" => %{
          "id" => note.id,
          "version" => note.version
        }
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "Only text changed"
      assert updated_note.data == original_data
      assert updated_note.tags == original_tags
      assert updated_note.name == note.name
    end
  end
end
