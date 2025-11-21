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
      assert metadata["id"] == note.id
      assert metadata["name"] == "Test Note"
    end

    test "returns error for non-existent note" do
      fake_id = Ash.UUID.generate()

      assert {:error, _error} = Sync.export_note(fake_id)
    end

    test "exports note with all metadata fields", %{note: note} do
      assert {:ok, {_markdown, json_string}} = Sync.export_note(note.id)

      metadata = Jason.decode!(json_string)

      assert metadata["id"]
      assert metadata["name"]
      assert metadata["note_type_id"]
      assert metadata["tags"]
      assert metadata["data"]
      assert metadata["version"]
      assert metadata["inserted_at"]
      assert metadata["updated_at"]
    end
  end
end
