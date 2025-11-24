defmodule Xeno.Sync.ImporterTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Sync.Importer

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
      note = Ash.load!(note, :file_path)

      change_attrs = %{
        "id" => note.id,
        "markdown_content" => "# Updated Content\n\nThis has been edited.",
        "version" => note.version,
        "path" => note.file_path
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "# Updated Content\n\nThis has been edited."
      assert updated_note.version == note.version + 1
    end

    test "imports change with updated metadata fields", %{note: note} do
      note = Ash.load!(note, :file_path)

      change_attrs = %{
        "id" => note.id,
        "markdown_content" => note.text,
        "version" => note.version,
        "name" => "Updated Name",
        "tags" => ["updated", "tags"],
        "data" => %{"key" => "updated"},
        "path" => note.file_path
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.name == "Updated Name"
      assert Enum.sort(updated_note.tags) == ["tags", "updated"]
      assert updated_note.data == %{"key" => "updated"}
    end

    test "returns error for version conflict (stale record)", %{note: note} do
      original_version = note.version

      %{version: 2} = Xeno.Content.Note.update!(note, %{text: "Concurrent edit"})

      change_attrs = %{
        "id" => note.id,
        "markdown_content" => "My edit",
        "version" => original_version
      }

      assert {:error, error} = Importer.import_change(change_attrs)
      assert error.class == :invalid
    end

    test "returns error for missing note", %{note: _note} do
      non_existent_id = Ash.UUID.generate()

      change_attrs = %{
        "id" => non_existent_id,
        "markdown_content" => "Content",
        "version" => 1
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.NoteNotFound{} = error
      assert error.provided_id == non_existent_id
      assert error.suggested_id == nil
      assert error.file_path == nil
    end

    test "preserves unchanged fields", %{note: note} do
      note = Ash.load!(note, :file_path)
      original_data = note.data
      original_tags = note.tags

      change_attrs = %{
        "id" => note.id,
        "markdown_content" => "Only text changed",
        "version" => note.version,
        "path" => note.file_path
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "Only text changed"
      assert updated_note.tags == original_tags
      assert updated_note.data == original_data
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
        "id" => wrong_id,
        "path" => "projects/work/meeting-notes",
        "markdown_content" => "Updated content",
        "version" => 1
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.NoteNotFound{} = error
      assert error.provided_id == wrong_id
      assert error.suggested_id == note.id
      assert error.file_path == "projects/work/meeting-notes"
      message = Exception.message(error)
      assert message =~ "not found"
      assert message =~ note.id
    end

    test "returns no suggestion when path doesn't exist" do
      wrong_id = Ash.UUID.generate()

      change_attrs = %{
        "id" => wrong_id,
        "path" => "nonexistent/path/note",
        "markdown_content" => "Content",
        "version" => 1
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.NoteNotFound{} = error
      assert error.provided_id == wrong_id
      assert error.suggested_id == nil
      assert error.file_path == "nonexistent/path/note"
      message = Exception.message(error)
      assert message =~ "not found"
      assert message =~ "No existing note at path"
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
        "id" => wrong_id,
        "path" => "docs/readme",
        "markdown_content" => "Content",
        "version" => 1
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.NoteNotFound{} = error
      assert error.suggested_id == docs_note.id
    end

    test "normal import still works when ID is correct", %{note: note} do
      change_attrs = %{
        "id" => note.id,
        "path" => "projects/work/meeting-notes",
        "markdown_content" => "Updated content",
        "version" => note.version
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "Updated content"
      assert updated_note.id == note.id
    end

    test "includes note name in suggestion message", %{note: note} do
      wrong_id = Ash.UUID.generate()

      change_attrs = %{
        "id" => wrong_id,
        "path" => "projects/work/meeting-notes",
        "markdown_content" => "Content",
        "version" => 1
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.NoteNotFound{} = error
      assert Exception.message(error) =~ note.name
    end

    test "returns error when ID exists but path doesn't match", %{note: note} do
      note = Ash.load!(note, :file_path)

      change_attrs = %{
        "id" => note.id,
        "path" => "wrong/path/location",
        "markdown_content" => "Content",
        "version" => note.version
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.PathMismatch{} = error
      assert error.note_id == note.id
      assert error.expected_path == note.file_path
      assert error.actual_path == "wrong/path/location"
      assert error.note_name == note.name
      message = Exception.message(error)
      assert message =~ "Path mismatch"
      assert message =~ note.file_path
      assert message =~ "wrong/path/location"
    end

    test "allows import when path is not provided (nil)", %{note: note} do
      change_attrs = %{
        "id" => note.id,
        "markdown_content" => "Updated without path",
        "version" => note.version
      }

      assert {:ok, updated_note} = Importer.import_change(change_attrs)
      assert updated_note.text == "Updated without path"
      assert updated_note.id == note.id
    end

    test "returns error for missing note without path" do
      non_existent_id = Ash.UUID.generate()

      change_attrs = %{
        "id" => non_existent_id,
        "markdown_content" => "Content",
        "version" => 1
      }

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Importer.import_change(change_attrs)
      assert %Xeno.Content.Errors.NoteNotFound{} = error
      assert error.provided_id == non_existent_id
      assert error.suggested_id == nil
      assert error.file_path == nil
    end
  end
end
