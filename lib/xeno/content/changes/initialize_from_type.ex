defmodule Xeno.Content.Changes.InitializeFromType do
  @moduledoc """
  Initializes a new Note with data from its NoteType template.

  Copies initial_text, initial_data, and initial_tags from the NoteType
  to the new Note. Only applies on create action.
  """

  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.action_type do
      :create ->
        initialize_from_type(changeset)

      _ ->
        changeset
    end
  end

  defp initialize_from_type(changeset) do
    note_type_id = Ash.Changeset.get_argument(changeset, :note_type_id)

    if note_type_id do
      case Xeno.Content.NoteType.get(note_type_id) do
        {:ok, note_type} ->
          changeset
          |> maybe_set(:text, note_type.initial_text)
          |> maybe_set(:data, note_type.initial_data)
          |> maybe_set(:tags, note_type.initial_tags)
          |> Ash.Changeset.manage_relationship(:note_type, note_type, type: :append)

        {:error, _} ->
          Ash.Changeset.add_error(changeset,
            field: :note_type_id,
            message: "NoteType not found"
          )
      end
    else
      changeset
    end
  end

  defp maybe_set(changeset, _attribute, initial) when is_nil(initial), do: changeset

  defp maybe_set(changeset, _attribute, []), do: changeset

  defp maybe_set(changeset, attribute, initial) do
    if not Ash.Changeset.changing_attribute?(changeset, attribute) do
      Ash.Changeset.force_change_attribute(changeset, attribute, initial)
    else
      changeset
    end
  end
end
