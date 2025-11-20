defmodule Xeno.Content.Changes.GenerateFilenameTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.Note

  setup do
    directory = generate(directory(path: "test_notes"))
    note_type = generate(note_type(name: "Test"))

    {:ok, directory: directory, note_type: note_type}
  end

  describe "generate_filename/2" do
    test "generates filename from name", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "My Note",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "my_note.md"
    end

    test "adds .md extension", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "simple",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert String.ends_with?(note.filename, ".md")
    end

    test "handles special characters", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Special! @#$ Characters%",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "special_characters.md"
    end

    test "collapses multiple underscores", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Multiple   Spaces",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "multiple_spaces.md"
    end

    test "only runs when filename not provided", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          filename: "custom.md",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "custom.md"
    end

    test "doesn't override explicit filename", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "This Would Generate Different Name",
          filename: "explicit_name.md",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "explicit_name.md"
    end

    test "removes leading and trailing underscores", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "!!!Note!!!",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "note.md"
    end
  end
end
