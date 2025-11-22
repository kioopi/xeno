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
    test "generates filename from name without extension", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "My Note",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "my_note"
    end

    test "does not add file extension", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "simple",
          directory_id: dir.id,
          note_type_id: type.id
        })

      refute String.contains?(note.filename, ".")
      assert note.filename == "simple"
    end

    test "handles special characters", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Special! @#$ Characters%",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "special_characters"
    end

    test "collapses multiple underscores", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Multiple   Spaces",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "multiple_spaces"
    end

    test "only runs when filename not provided", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          filename: "custom",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "custom"
    end

    test "doesn't override explicit filename", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "This Would Generate Different Name",
          filename: "explicit_name",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "explicit_name"
    end

    test "removes leading and trailing underscores", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "!!!Note!!!",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.filename == "note"
    end
  end
end
