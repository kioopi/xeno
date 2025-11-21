defmodule Xeno.Sync.TreeBuilderTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Sync.TreeBuilder

  describe "directory_to_path/1" do
    test "converts single directory to path string" do
      directory = generate(directory(path: "notes"))

      path = TreeBuilder.directory_to_path(directory)

      assert path == "notes"
    end

    test "handles nested directory hierarchy" do
      directory = generate(directory(path: "projects/web_app"))

      path = TreeBuilder.directory_to_path(directory)

      assert path == "projects/web_app"
    end

    test "handles deeply nested directories" do
      directory = generate(directory(path: "work/projects/2024/q1"))

      path = TreeBuilder.directory_to_path(directory)

      assert path == "work/projects/2024/q1"
    end
  end

  describe "note_file_path/1" do
    test "combines directory path with note filename" do
      directory = generate(directory(path: "projects"))
      note_type = generate(note_type(name: "Note"))

      note = generate(
        note(
          name: "Architecture",
          filename: "architecture.md",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      note = Ash.get!(Xeno.Content.Note, note.id, load: [:directory])

      file_path = TreeBuilder.note_file_path(note)

      assert file_path == "projects/architecture"
    end

    test "handles nested directory paths" do
      directory = generate(directory(path: "work/docs"))
      note_type = generate(note_type(name: "Note"))

      note = generate(
        note(
          name: "Meeting Notes",
          filename: "meeting_notes.md",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      note = Ash.get!(Xeno.Content.Note, note.id, load: [:directory])

      file_path = TreeBuilder.note_file_path(note)

      assert file_path == "work/docs/meeting_notes"
    end

    test "strips .md extension from filename" do
      directory = generate(directory(path: "notes"))
      note_type = generate(note_type(name: "Note"))

      note = generate(
        note(
          name: "Test",
          filename: "test.md",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      note = Ash.get!(Xeno.Content.Note, note.id, load: [:directory])

      file_path = TreeBuilder.note_file_path(note)

      assert file_path == "notes/test"
    end
  end

  describe "build_sync_tree/0" do
    test "returns list of {note, path} tuples" do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note = generate(
        note(
          name: "Test Note",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      result = TreeBuilder.build_sync_tree()

      assert is_list(result)
      assert Enum.any?(result, fn {n, _path} -> n.id == note.id end)
    end

    test "includes correct paths for all notes" do
      dir1 = generate(directory(path: "projects"))
      dir2 = generate(directory(path: "personal"))
      note_type = generate(note_type(name: "Note"))

      note1 = generate(
        note(
          name: "Project Note",
          filename: "project_note.md",
          directory_id: dir1.id,
          note_type_id: note_type.id
        )
      )

      note2 = generate(
        note(
          name: "Personal Note",
          filename: "personal_note.md",
          directory_id: dir2.id,
          note_type_id: note_type.id
        )
      )

      result = TreeBuilder.build_sync_tree()

      assert {_note, "projects/project_note"} =
        Enum.find(result, fn {n, _} -> n.id == note1.id end)

      assert {_note, "personal/personal_note"} =
        Enum.find(result, fn {n, _} -> n.id == note2.id end)
    end

    test "handles notes in nested directories" do
      _parent_dir = generate(directory(path: "work"))
      nested_dir = generate(directory(path: "work/projects"))
      note_type = generate(note_type(name: "Note"))

      note = generate(
        note(
          name: "Nested Note",
          filename: "nested.md",
          directory_id: nested_dir.id,
          note_type_id: note_type.id
        )
      )

      result = TreeBuilder.build_sync_tree()

      assert {_note, "work/projects/nested"} =
        Enum.find(result, fn {n, _} -> n.id == note.id end)
    end

    test "returns empty list when no notes exist" do
      # Delete all notes individually to respect optimistic locking
      Xeno.Content.Note
      |> Ash.read!()
      |> Enum.each(&Xeno.Content.Note.destroy/1)

      result = TreeBuilder.build_sync_tree()

      assert result == []
    end
  end
end
