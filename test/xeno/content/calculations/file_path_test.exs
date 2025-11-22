defmodule Xeno.Content.Calculations.FilePathTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.Note

  describe "file_path calculation" do
    test "returns correct path for nested directory" do
      note_type = generate(note_type(name: "Test Type"))
      work_dir = generate(directory(path: "projects/work", name: "Work"))

      note =
        generate(
          note(
            name: "Meeting Notes",
            filename: "meeting-notes",
            note_type_id: note_type.id,
            directory_id: work_dir.id
          )
        )

      note = Note.get!(note.id, load: [:file_path])

      assert note.file_path == "projects/work/meeting-notes"
    end

    test "returns correct path for single-level directory" do
      note_type = generate(note_type(name: "Test Type"))
      docs_dir = generate(directory(path: "docs", name: "Docs"))

      note =
        generate(
          note(
            name: "Readme",
            filename: "readme",
            note_type_id: note_type.id,
            directory_id: docs_dir.id
          )
        )

      note = Note.get!(note.id, load: [:file_path])

      assert note.file_path == "docs/readme"
    end

    test "handles notes with existing .md extension during transition" do
      note_type = generate(note_type(name: "Test Type"))
      docs_dir = generate(directory(path: "docs", name: "Docs"))

      note =
        generate(
          note(
            name: "Legacy Note",
            filename: "legacy.md",
            note_type_id: note_type.id,
            directory_id: docs_dir.id
          )
        )

      note = Note.get!(note.id, load: [:file_path])

      assert note.file_path == "docs/legacy.md"
    end

    test "works with directory preloaded" do
      note_type = generate(note_type(name: "Test Type"))
      projects_dir = generate(directory(path: "projects", name: "Projects"))

      note =
        generate(
          note(
            name: "Project Plan",
            filename: "plan",
            note_type_id: note_type.id,
            directory_id: projects_dir.id
          )
        )

      note = Note.get!(note.id, load: [:directory, :file_path])

      assert note.directory.path == "projects"
      assert note.file_path == "projects/plan"
    end

    test "handles deeply nested directory structure" do
      note_type = generate(note_type(name: "Test Type"))
      deep_dir = generate(directory(path: "foo/bar/baz/qux", name: "Qux"))

      note =
        generate(
          note(
            name: "Deep Note",
            filename: "deep-note",
            note_type_id: note_type.id,
            directory_id: deep_dir.id
          )
        )

      note = Note.get!(note.id, load: [:file_path])

      assert note.file_path == "foo/bar/baz/qux/deep-note"
    end

    test "handles filenames with special characters" do
      note_type = generate(note_type(name: "Test Type"))
      docs_dir = generate(directory(path: "docs", name: "Docs"))

      note =
        generate(
          note(
            name: "Note with Dashes",
            filename: "note-with-dashes-and_underscores",
            note_type_id: note_type.id,
            directory_id: docs_dir.id
          )
        )

      note = Note.get!(note.id, load: [:file_path])

      assert note.file_path == "docs/note-with-dashes-and_underscores"
    end
  end
end
