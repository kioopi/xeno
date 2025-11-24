defmodule Xeno.Content.NoteTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.Note

  setup do
    directory = generate(directory(path: "test_notes"))

    note_type =
      generate(
        note_type(
          name: "Test Template",
          initial_text: "Template text",
          initial_data: %{"key" => "value"},
          initial_tags: ["template", "test"]
        )
      )

    {:ok, directory: directory, note_type: note_type}
  end

  describe "create/1" do
    test "creates note from note type template", %{directory: dir, note_type: type} do
      attrs = %{
        name: "My Note",
        directory_id: dir.id,
        note_type_id: type.id
      }

      assert {:ok, note} = Note.create(attrs)
      assert note.name == "My Note"
      assert note.filename == "my_note"
      assert note.text == "Template text"
      assert note.data == %{"key" => "value"}
      assert note.tags == ["template", "test"]
      assert note.version == 1
    end

    test "generates filename from name when not provided", %{directory: dir, note_type: type} do
      attrs = %{
        name: "Special Characters! & Spaces",
        directory_id: dir.id,
        note_type_id: type.id
      }

      assert {:ok, note} = Note.create(attrs)
      assert note.filename == "special_characters_spaces"
    end

    test "uses provided filename when given", %{directory: dir, note_type: type} do
      attrs = %{
        name: "My Note",
        filename: "custom_filename",
        directory_id: dir.id,
        note_type_id: type.id
      }

      assert {:ok, note} = Note.create(attrs)
      assert note.filename == "custom_filename"
    end

    test "enforces unique filename within directory", %{directory: dir, note_type: type} do
      attrs = %{
        name: "First",
        filename: "same",
        directory_id: dir.id,
        note_type_id: type.id
      }

      assert {:ok, _} = Note.create(attrs)

      assert {:error, error} = Note.create(attrs)
      assert Exception.message(error) =~ "unique"
    end

    test "allows same filename in different directories", %{note_type: type} do
      dir1 = generate(directory(path: "dir1"))
      dir2 = generate(directory(path: "dir2"))

      attrs1 = %{
        name: "Note",
        filename: "same",
        directory_id: dir1.id,
        note_type_id: type.id
      }

      attrs2 = %{
        name: "Note",
        filename: "same",
        directory_id: dir2.id,
        note_type_id: type.id
      }

      assert {:ok, _} = Note.create(attrs1)
      assert {:ok, _} = Note.create(attrs2)
    end

    test "normalizes tags on create", %{directory: dir, note_type: type} do
      attrs = %{
        name: "Tagged Note",
        directory_id: dir.id,
        note_type_id: type.id,
        tags: ["  UPPERCASE  ", "lowercase", "MiXeD", "uppercase", " trim "]
      }

      assert {:ok, note} = Note.create(attrs)
      assert note.tags == ["lowercase", "mixed", "trim", "uppercase"]
    end

    test "requires note_type_id", %{directory: dir} do
      attrs = %{
        name: "No Type",
        directory_id: dir.id
      }

      assert {:error, error} = Note.create(attrs)
      assert Exception.message(error) =~ "required"
    end

    test "can override template values", %{directory: dir, note_type: type} do
      attrs = %{
        name: "Custom",
        directory_id: dir.id,
        note_type_id: type.id,
        text: "Override text",
        data: %{"different" => "data"},
        tags: ["custom"]
      }

      assert {:ok, note} = Note.create(attrs)
      assert note.text == "Override text"
      assert note.data == %{"different" => "data"}
      assert note.tags == ["custom"]
    end
  end

  describe "update/2" do
    setup %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Original",
          directory_id: dir.id,
          note_type_id: type.id
        })

      {:ok, note: note}
    end

    test "updates note fields", %{note: note} do
      assert {:ok, updated} =
               Note.update(note, %{
                 name: "Updated Name",
                 text: "New text content"
               })

      assert updated.name == "Updated Name"
      assert updated.text == "New text content"
      assert updated.version == 2
    end

    test "normalizes tags on update", %{note: note} do
      assert {:ok, updated} =
               Note.update(note, %{
                 tags: ["NEW", "  old  ", "new"]
               })

      assert updated.tags == ["new", "old"]
    end

    test "optimistic locking prevents concurrent updates", %{note: note} do
      assert {:ok, updated_v2} = Note.update(note, %{text: "Update A"})
      assert updated_v2.version == 2

      assert {:error, error} = Note.update(note, %{text: "Update B"})

      assert Exception.message(error) =~ "stale"
    end
  end

  describe "destroy/1" do
    test "deletes note", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "To Delete",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert :ok = Note.destroy(note)

      assert {:error, error} = Note.get(note.id)
      assert Exception.message(error) =~ "not found"
    end
  end

  describe "by_filename/2" do
    test "finds note by directory and filename", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Findable",
          filename: "find_me",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert {:ok, found} = Note.by_filename(dir.id, "find_me")
      assert found.id == note.id
    end
  end

  describe "by_file_path/1" do
    test "finds note by file path with nested directory" do
      note_type = generate(note_type(name: "Test Type"))
      work_dir = generate(directory(path: "projects/work", name: "Work"))

      {:ok, note} =
        Note.create(%{
          name: "Meeting Notes",
          filename: "meeting-notes",
          directory_id: work_dir.id,
          note_type_id: note_type.id
        })

      assert {:ok, found} = Note.by_file_path("projects/work/meeting-notes")
      assert found.id == note.id
      assert found.filename == "meeting-notes"
    end

    test "finds note by file path with single-level directory" do
      note_type = generate(note_type(name: "Test Type"))
      docs_dir = generate(directory(path: "docs", name: "Docs"))

      {:ok, note} =
        Note.create(%{
          name: "Readme",
          filename: "readme",
          directory_id: docs_dir.id,
          note_type_id: note_type.id
        })

      assert {:ok, found} = Note.by_file_path("docs/readme")
      assert found.id == note.id
    end

    test "returns error for non-existent path" do
      assert {:error, error} = Note.by_file_path("nonexistent/path/note")
      assert Exception.message(error) =~ "not found"
    end

    test "returns error for invalid path format" do
      assert {:error, error} = Note.by_file_path("")
      assert Exception.message(error) =~ "Invalid file path"
    end

    test "returns error for path without directory" do
      assert {:error, error} = Note.by_file_path("note")
      assert Exception.message(error) =~ "Invalid file path"
    end

    test "handles deeply nested directory structure" do
      note_type = generate(note_type(name: "Test Type"))
      deep_dir = generate(directory(path: "foo/bar/baz/qux", name: "Qux"))

      {:ok, note} =
        Note.create(%{
          name: "Deep Note",
          filename: "deep-note",
          directory_id: deep_dir.id,
          note_type_id: note_type.id
        })

      assert {:ok, found} = Note.by_file_path("foo/bar/baz/qux/deep-note")
      assert found.id == note.id
    end
  end

  describe "timestamps" do
    test "sets inserted_at and updated_at on creation", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Timestamped",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert %DateTime{} = note.inserted_at
      assert %DateTime{} = note.updated_at
    end
  end

  describe "import_from_filesystem" do
    setup do
      note_type = generate(note_type(name: "Test Type"))
      dir = generate(directory(path: "foo/bar", name: "Bar"))

      note =
        Note.create!(%{
          name: "Note",
          filename: "note",
          directory_id: dir.id,
          note_type_id: note_type.id,
          text: "the old text",
          tags: ["one", "two"]
        })

      {:ok, dir: dir, note_type: note_type, note: note}
    end

    test "updates a note", %{ note: note } do
      params = %{
        id: note.id,
        path: "foo/bar/note",
        markdown_content: "the new text",
        version: note.version
      }

      assert {:ok, updated} = Note.import_from_filesystem(params)
      assert updated.id == note.id
      assert updated.text == "the new text"
      assert updated.name == "Note"
      assert updated.tags == ["one", "two"]
      assert updated.version == 2
    end

    test "optimistic locking prevents concurrent updates", %{note: note} do
      assert updated = Note.update!(note, %{text: "Update A"})
      assert updated.version == 2

      assert {:error, error} = Note.import_from_filesystem(%{
        id: note.id,
        path: "foo/bar/note",
        markdown_content: "the new text",
        version: 1
      })

      assert Exception.message(error) =~ "stale"
    end
  end
end
