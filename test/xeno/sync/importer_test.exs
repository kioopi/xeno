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

  describe "parse_note_path/1" do
    test "parses nested path correctly" do
      assert {:ok, "projects/work", "meeting-notes"} =
               Importer.parse_note_path("projects/work/meeting-notes")
    end

    test "parses deeply nested path" do
      assert {:ok, "foo/bar/baz/qux", "note"} = Importer.parse_note_path("foo/bar/baz/qux/note")
    end

    test "handles path with single directory" do
      assert {:ok, "projects", "note"} = Importer.parse_note_path("projects/note")
    end

    test "handles simple directory/filename pattern" do
      assert {:ok, "docs", "readme"} = Importer.parse_note_path("docs/readme")
    end

    test "returns error for empty path" do
      assert {:error, :invalid_path} = Importer.parse_note_path("")
    end

    test "returns error for nil path" do
      assert {:error, :invalid_path} = Importer.parse_note_path(nil)
    end

    test "returns error for path ending with slash" do
      assert {:error, :invalid_path} = Importer.parse_note_path("projects/work/")
    end

    test "returns error for single filename without directory" do
      assert {:error, :invalid_path} = Importer.parse_note_path("my-note")
    end
  end

  describe "find_note_by_path/1" do
    setup do
      note_type = generate(note_type(name: "Test Type"))

      docs_dir = generate(directory(path: "docs", name: "Docs"))
      projects_dir = generate(directory(path: "projects", name: "Projects"))
      work_dir = generate(directory(path: "projects/work", name: "Work"))

      docs_note =
        generate(
          note(
            name: "Docs Note",
            filename: "readme",
            note_type_id: note_type.id,
            directory_id: docs_dir.id
          )
        )

      project_note =
        generate(
          note(
            name: "Project Note",
            filename: "project-note",
            note_type_id: note_type.id,
            directory_id: projects_dir.id
          )
        )

      work_note =
        generate(
          note(
            name: "Work Note",
            filename: "meeting-notes",
            note_type_id: note_type.id,
            directory_id: work_dir.id
          )
        )

      %{
        docs_note: docs_note,
        project_note: project_note,
        work_note: work_note,
        docs_dir: docs_dir,
        projects_dir: projects_dir,
        work_dir: work_dir
      }
    end

    test "finds note at nested path", %{work_note: work_note} do
      assert {:ok, found_note} = Importer.find_note_by_path("projects/work/meeting-notes")
      assert found_note.id == work_note.id
      assert found_note.filename == "meeting-notes"
    end

    test "finds note in single-level directory", %{docs_note: docs_note} do
      assert {:ok, found_note} = Importer.find_note_by_path("docs/readme")
      assert found_note.id == docs_note.id
    end

    test "finds note in another single-level directory", %{project_note: project_note} do
      assert {:ok, found_note} = Importer.find_note_by_path("projects/project-note")
      assert found_note.id == project_note.id
    end

    test "returns error for non-existent path" do
      assert {:error, :not_found} = Importer.find_note_by_path("nonexistent/path/note")
    end

    test "returns error for non-existent note in existing directory", %{work_dir: _work_dir} do
      assert {:error, :not_found} = Importer.find_note_by_path("projects/work/nonexistent-note")
    end

    test "returns error for invalid path format" do
      assert {:error, :invalid_path} = Importer.find_note_by_path("")
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

  describe "import_change/1 with ID suggestion" do
    setup do
      note_type = generate(note_type(name: "Test Type"))
      work_dir = generate(directory(path: "projects/work"))

      note =
        generate(
          note(
            name: "Meeting Notes",
            filename: "meeting-notes",
            text: "Original content",
            note_type_id: note_type.id,
            directory_id: work_dir.id
          )
        )

      %{note: note, directory: work_dir}
    end

    test "suggests correct ID when provided ID not found but path exists", %{note: note} do
      wrong_id = Ash.UUID.generate()

      change_attrs = %{
        "note_id" => wrong_id,
        "path" => "projects/work/meeting-notes",
        "markdown_content" => "Updated content",
        "metadata" => %{
          "id" => wrong_id,
          "version" => 1
        }
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.type == :id_not_found
      assert error.provided_id == wrong_id
      assert error.suggested_id == note.id
      assert error.path == "projects/work/meeting-notes"
      assert error.message =~ "not found"
      assert error.message =~ note.id
    end

    test "returns no suggestion when path doesn't exist" do
      wrong_id = Ash.UUID.generate()

      change_attrs = %{
        "note_id" => wrong_id,
        "path" => "nonexistent/path/note",
        "markdown_content" => "Content",
        "metadata" => %{
          "id" => wrong_id,
          "version" => 1
        }
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.type == :id_not_found
      assert error.provided_id == wrong_id
      assert error.suggested_id == nil
      assert error.path == "nonexistent/path/note"
      assert error.message =~ "not found"
      assert error.message =~ "No existing note at path"
    end

    test "handles simple directory/note pattern in suggestions" do
      note_type = generate(note_type(name: "Docs Type"))
      docs_dir = generate(directory(path: "docs", name: "Docs"))

      docs_note =
        generate(
          note(
            name: "Readme",
            filename: "readme",
            note_type_id: note_type.id,
            directory_id: docs_dir.id
          )
        )

      wrong_id = Ash.UUID.generate()

      change_attrs = %{
        "note_id" => wrong_id,
        "path" => "docs/readme",
        "markdown_content" => "Content",
        "metadata" => %{
          "id" => wrong_id,
          "version" => 1
        }
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.type == :id_not_found
      assert error.suggested_id == docs_note.id
    end

    test "normal import still works when ID is correct", %{note: note} do
      change_attrs = %{
        "note_id" => note.id,
        "path" => "projects/work/meeting-notes",
        "markdown_content" => "Updated content",
        "metadata" => %{
          "id" => note.id,
          "version" => note.version
        }
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "Updated content"
      assert updated_note.id == note.id
    end

    test "includes note name in suggestion message", %{note: note} do
      wrong_id = Ash.UUID.generate()

      change_attrs = %{
        "note_id" => wrong_id,
        "path" => "projects/work/meeting-notes",
        "markdown_content" => "Content",
        "metadata" => %{
          "id" => wrong_id,
          "version" => 1
        }
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.message =~ note.name
    end
  end
end
