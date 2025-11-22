defmodule Xeno.SyncTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Sync

  setup do
    directory = generate(directory(path: "test_sync"))
    note_type = generate(note_type(name: "Test Type"))

    {:ok, note} =
      Xeno.Content.Note.create(%{
        name: "Test Note",
        filename: "test_note.md",
        text: "Test content",
        data: %{"key" => "value"},
        tags: ["test"],
        directory_id: directory.id,
        note_type_id: note_type.id
      })

    note = Ash.get!(Xeno.Content.Note, note.id, load: [:directory, :note_type])

    {:ok, note: note, directory: directory, note_type: note_type}
  end

  describe "export_all/0" do
    test "returns all notes with paths", %{note: note} do
      result = Sync.export_all()

      assert is_list(result)
      assert Enum.any?(result, fn {n, _path} -> n.id == note.id end)
    end

    test "includes correct path for each note", %{note: note} do
      result = Sync.export_all()

      assert {_note, "test_sync/test_note"} =
        Enum.find(result, fn {n, _} -> n.id == note.id end)
    end

    test "returns empty list when no notes exist" do
      Xeno.Content.Note
      |> Ash.read!()
      |> Enum.each(&Xeno.Content.Note.destroy/1)

      result = Sync.export_all()

      assert result == []
    end
  end

  describe "export_note/1" do
    test "returns single note's markdown and json", %{note: note} do
      assert {:ok, {markdown, json_string}} = Sync.export_note(note.id)

      assert is_binary(markdown)
      assert is_binary(json_string)

      assert markdown =~ "Test content"

      metadata = Jason.decode!(json_string)
      assert metadata["_id"] == note.id
      assert metadata["name"] == "Test Note"
    end

    test "returns error for non-existent note" do
      fake_id = Ash.UUID.generate()

      assert {:error, _error} = Sync.export_note(fake_id)
    end

    test "exports note with all metadata fields", %{note: note} do
      assert {:ok, {_markdown, json_string}} = Sync.export_note(note.id)

      metadata = Jason.decode!(json_string)

      assert metadata["_id"]
      assert metadata["_schema_version"] == "1.0"
      assert metadata["name"]
      assert metadata["tags"]
      assert metadata["data"]
      refute metadata["version"]
      refute metadata["note_type_id"]
      refute metadata["inserted_at"]
      refute metadata["updated_at"]
    end
  end

  describe "import_change/1" do
    test "delegates to Importer.import_change/1", %{note: note} do
      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => "Updated content",
        "metadata" => %{
          "id" => note.id,
          "version" => note.version
        }
      }

      assert {:ok, updated_note} = Sync.import_change(change_attrs)
      assert updated_note.text == "Updated content"
    end

    test "returns error for invalid change", %{note: note} do
      change_attrs = %{
        "note_id" => note.id,
        "markdown_content" => "Content",
        "metadata" => %{
          "version" => note.version
        }
      }

      assert {:error, _reason} = Sync.import_change(change_attrs)
    end
  end

  describe "import_changes/1" do
    test "processes batch of changes successfully", %{note: note, directory: directory, note_type: note_type} do
      {:ok, note2} =
        Xeno.Content.Note.create(%{
          name: "Second Note",
          filename: "second_note.md",
          text: "Second content",
          directory_id: directory.id,
          note_type_id: note_type.id
        })

      changes = [
        %{
          "note_id" => note.id,
          "markdown_content" => "Updated first",
          "metadata" => %{"id" => note.id, "version" => note.version}
        },
        %{
          "note_id" => note2.id,
          "markdown_content" => "Updated second",
          "metadata" => %{"id" => note2.id, "version" => note2.version}
        }
      ]

      assert {:ok, result} = Sync.import_changes(changes)
      assert result.imported == 2
      assert result.failed == 0
      assert result.errors == []
    end

    test "reports failures and successes separately", %{note: note} do
      fake_id = Ash.UUID.generate()

      changes = [
        %{
          "note_id" => note.id,
          "markdown_content" => "Valid update",
          "metadata" => %{"id" => note.id, "version" => note.version}
        },
        %{
          "note_id" => fake_id,
          "markdown_content" => "Invalid - note doesn't exist",
          "metadata" => %{"id" => fake_id, "version" => 1}
        }
      ]

      assert {:ok, result} = Sync.import_changes(changes)
      assert result.imported == 1
      assert result.failed == 1
      assert length(result.errors) == 1
    end

    test "continues processing after individual failures", %{note: note, directory: directory, note_type: note_type} do
      Xeno.Content.Note.update!(note, %{text: "Concurrent edit"})

      {:ok, note2} =
        Xeno.Content.Note.create(%{
          name: "Second Note",
          filename: "second_note.md",
          text: "Second content",
          directory_id: directory.id,
          note_type_id: note_type.id
        })

      changes = [
        %{
          "note_id" => note.id,
          "markdown_content" => "Should fail - version conflict",
          "metadata" => %{"id" => note.id, "version" => 1}
        },
        %{
          "note_id" => note2.id,
          "markdown_content" => "Should succeed",
          "metadata" => %{"id" => note2.id, "version" => note2.version}
        }
      ]

      assert {:ok, result} = Sync.import_changes(changes)
      assert result.imported == 1
      assert result.failed == 1
    end

    test "returns summary statistics", %{note: note} do
      changes = [
        %{
          "note_id" => note.id,
          "markdown_content" => "Updated",
          "metadata" => %{"id" => note.id, "version" => note.version}
        }
      ]

      assert {:ok, result} = Sync.import_changes(changes)
      assert Map.has_key?(result, :imported)
      assert Map.has_key?(result, :failed)
      assert Map.has_key?(result, :errors)
    end
  end
end
