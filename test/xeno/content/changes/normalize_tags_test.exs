defmodule Xeno.Content.Changes.NormalizeTagsTest do
  use Xeno.DataCase, async: true

  alias Xeno.Content
  alias Content.Note
  alias Content.NoteType
  alias Xeno.Files.Directory

  setup do
    {:ok, directory} = Directory.create("test_notes")
    {:ok, note_type} = NoteType.create(%{name: "Test"})

    {:ok, directory: directory, note_type: note_type}
  end

  describe "normalize_tags/2" do
    test "lowercases tags", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: ["UPPERCASE", "MiXeD"]
        })

      assert note.tags == ["mixed", "uppercase"]
    end

    test "trims whitespace from tags", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: ["  spaced  ", " trimmed "]
        })

      assert note.tags == ["spaced", "trimmed"]
    end

    test "removes duplicate tags", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: ["duplicate", "DUPLICATE", "unique"]
        })

      assert note.tags == ["duplicate", "unique"]
    end

    test "filters out empty tags", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: ["valid", "", "  ", "also_valid"]
        })

      assert note.tags == ["also_valid", "valid"]
    end

    test "handles nil tags", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: nil
        })

      assert is_nil(note.tags)
    end

    test "works on update action", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: ["original"]
        })

      {:ok, updated} = Note.update(note, %{tags: ["  UPDATED  ", "new"]})

      assert updated.tags == ["new", "updated"]
    end
  end
end
