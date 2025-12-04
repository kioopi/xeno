defmodule Xeno.Content.Changes.ChangesAndFormsTest do
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

  describe "Do changes show up in forms after validation" do
    test "do they", %{directory: dir} do
      note_type =
        generate(
          note_type(
            name: "with inital_text",
            initial_text: "initex"
          )
        )

      ash_form = Xeno.Content.form_to_create_note()
      IO.inspect(ash_form, label: "Ash form")

      form = Phoenix.Component.to_form(ash_form, [])

      IO.inspect(form, label: "PHX form before validate")

      form =
        AshPhoenix.Form.validate(form, %{
          note_type_id: note_type.id
        })

      IO.inspect(form, label: "PHX form after validate")

      assert form.params.note_type_id == note_type.id, "Params did not set note_type_id"

      refute Map.has_key?(form.params, :text),
             "Text unexpectedly has been set on the phx form by the change"

      # form = Phoenix.Component.to_form(form.source, [])

      # form = AshPhoenix.Form.validate(form, form.source.source.attributes)

      form = AshPhoenix.Form.update_params(form, &Map.merge(&1, form.source.source.attributes))

      IO.inspect(form, label: "PHX form after to_forming form source")

      assert form.params.text == "initex", "Change did not set text attribute"
    end

    test "does not overwrite changes", %{directory: dir} do
      note_type =
        generate(
          note_type(
            name: "with inital_text",
            initial_text: "initex"
          )
        )

      # IO.inspect(note_type, label: "note_type")

      cs =
        Changeset.for_create(Note, :create, %{
          name: "Test",
          directory_id: dir.id,
          note_type_id: note_type.id,
          text: "custom text"
        })

      # IO.inspect(cs, label: "changeset before")

      options = %{}
      context = %{}

      cs = SetNoteType.change(cs, options, context)

      assert Changeset.fetch_change(cs, :text) == {:ok, "custom text"}
    end
  end
end
