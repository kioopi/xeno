defmodule Xeno.Content.Changes.SetNoteTypeTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.Note
  alias Xeno.Content.Changes.SetNoteType
  alias Ash.Changeset

  setup do
    directory = generate(directory(path: "test_notes"))
    note_type = generate(note_type(name: "Test"))

    {:ok, directory: directory, note_type: note_type}
  end

  describe "SetNoteType change" do
    test "sets text from inital_text", %{directory: dir} do
      note_type =
        generate(
          note_type(
            name: "with inital_text",
            initial_text: "initex"
          )
        )

      cs =
        Changeset.for_create(Note, :create, %{
          name: "Test",
          directory_id: dir.id,
          note_type_id: note_type.id
        })

      options = %{}
      context = %{}

      cs = SetNoteType.change(cs, options, context)

      assert Changeset.fetch_change(cs, :text) == {:ok, "initex"}
    end

    test "does not overwrite changes", %{directory: dir} do
      note_type =
        generate(
          note_type(
            name: "with inital_text",
            initial_text: "initex"
          )
        )

      cs =
        Changeset.for_create(Note, :create, %{
          name: "Test",
          directory_id: dir.id,
          note_type_id: note_type.id,
          text: "custom text"
        })

      options = %{}
      context = %{}

      cs = SetNoteType.change(cs, options, context)

      assert Changeset.fetch_change(cs, :text) == {:ok, "custom text"}
    end
  end
end
