defmodule Xeno.Content.Changes.InitializeFromTypeTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.{Note, NoteType}

  setup do
    directory = generate(directory(path: "test_notes"))

    note_type =
      generate(
        note_type(
          name: "Template",
          initial_text: "Default text",
          initial_data: %{"config" => "value"},
          initial_tags: ["tag1", "tag2"]
        )
      )

    {:ok, directory: directory, note_type: note_type}
  end

  describe "initialize_from_type/2" do
    test "copies initial_text from NoteType", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.text == "Default text"
    end

    test "copies initial_data from NoteType", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.data == %{"config" => "value"}
    end

    test "copies initial_tags from NoteType", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.tags == ["tag1", "tag2"]
    end

    test "allows overriding template text", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          text: "Custom text"
        })

      assert note.text == "Custom text"
    end

    test "allows overriding template data", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          data: %{"custom" => "data"}
        })

      assert note.data == %{"custom" => "data"}
    end

    test "allows overriding template tags", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id,
          tags: ["custom"]
        })

      assert note.tags == ["custom"]
    end

    test "only runs on create action", %{directory: dir, note_type: type} do
      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: type.id
        })

      assert note.text == "Default text"

      {:ok, updated} = Note.update(note, %{name: "Updated"})

      assert updated.text == "Default text"
    end

    test "handles NoteType with nil initial values", %{directory: dir} do
      {:ok, empty_type} =
        NoteType.create(%{
          name: "Empty",
          initial_text: nil,
          initial_data: nil,
          initial_tags: nil
        })

      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: empty_type.id
        })

      assert is_nil(note.text)
      assert is_nil(note.data)
      assert is_nil(note.tags)
    end

    test "does not copy empty initial_tags list", %{directory: dir} do
      {:ok, empty_tags_type} =
        NoteType.create(%{
          name: "EmptyTags",
          initial_text: "Some text",
          initial_tags: []
        })

      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: empty_tags_type.id
        })

      assert note.text == "Some text"
      assert is_nil(note.tags) or note.tags == []
    end

    test "handles empty string initial_text as nil", %{directory: dir} do
      {:ok, empty_text_type} =
        NoteType.create(%{
          name: "EmptyText",
          initial_text: ""
        })

      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: empty_text_type.id
        })

      assert is_nil(note.text)
    end

    test "copies empty map initial_data", %{directory: dir} do
      {:ok, empty_data_type} =
        NoteType.create(%{
          name: "EmptyData",
          initial_data: %{}
        })

      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: empty_data_type.id
        })

      assert note.data == %{}
    end

    test "copies only non-nil template values", %{directory: dir} do
      {:ok, partial_type} =
        NoteType.create(%{
          name: "Partial",
          initial_text: "Has text",
          initial_data: nil,
          initial_tags: ["tag1"]
        })

      {:ok, note} =
        Note.create(%{
          name: "Test",
          directory_id: dir.id,
          note_type_id: partial_type.id
        })

      assert note.text == "Has text"
      assert is_nil(note.data)
      assert note.tags == ["tag1"]
    end
  end
end
