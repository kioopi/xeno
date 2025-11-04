defmodule Notes.Notes.Changes.GenerateName do
  @moduledoc """
  Generates a human-readable name from a filesystem-friendly filename.

  This change only runs when the name attribute is not provided but the filename attribute is.
  It transforms the filename by:
  - Replacing underscores with spaces
  - Capitalizing the first letter of each word
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Only generate name if it's not already being changed and filename is being changed
    if not Ash.Changeset.changing_attribute?(changeset, :name) and
         Ash.Changeset.changing_attribute?(changeset, :filename) do
      case Ash.Changeset.get_attribute(changeset, :filename) do
        nil ->
          changeset

        filename when is_binary(filename) ->
          name = generate_name(filename)
          Ash.Changeset.force_change_attribute(changeset, :name, name)
      end
    else
      changeset
    end
  end

  defp generate_name(filename) do
    filename
    # Replace underscores with spaces
    |> String.replace("_", " ")
    # Capitalize each word
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
