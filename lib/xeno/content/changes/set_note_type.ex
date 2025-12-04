defmodule Xeno.Content.Changes.SetNoteType do
  @moduledoc """
  Sets attributes from defaults of a NoteType when creating or changing a Note.
  """
  use Ash.Resource.Change
  alias Ash.Changeset
  alias Xeno.Content.NoteType

  @impl true
  def change(changeset, _opts, _context) do
    case Changeset.fetch_change(changeset, :note_type_id) do
      :error ->
        changeset

      {:ok, note_type_id} ->
        case NoteType.get(note_type_id, load: :note_params) do
          {:ok, note_type} ->
            set_note_attributes(changeset, note_type)

          {:error, _} ->
            Changeset.add_error(changeset,
              field: :note_type_id,
              message: "NoteType not found"
            )
        end
    end
  end

  def set_note_attributes(changeset, note_type) do
    Enum.reduce(note_type.note_params || %{}, changeset, fn {attr_name, initial}, cs ->
      attribute = String.to_existing_atom(attr_name)

      if !Changeset.changing_attribute?(cs, attribute) do
        Changeset.force_change_attribute(cs, attribute, initial)
      else
        changeset
      end
    end)
  end
end
