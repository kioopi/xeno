defmodule Xeno.Files.Changes.GenerateFilename do
  @moduledoc """
  Generates a filesystem-friendly filename from a human-readable name.

  This change only runs when the filename attribute is not provided but the name attribute is.
  It transforms the name by:
  - Converting to lowercase
  - Replacing non-alphanumeric characters (except underscores) with underscores
  - Collapsing multiple consecutive underscores into a single underscore
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Only generate filename if it's not already being changed and name is being changed
    if not Ash.Changeset.changing_attribute?(changeset, :filename) and
         Ash.Changeset.changing_attribute?(changeset, :name) do
      case Ash.Changeset.get_attribute(changeset, :name) do
        nil ->
          changeset

        name when is_binary(name) ->
          filename = generate_filename(name)
          Ash.Changeset.force_change_attribute(changeset, :filename, filename)
      end
    else
      changeset
    end
  end

  defp generate_filename(name) do
    name
    |> String.downcase()
    # Replace any non-alphanumeric character (except underscore) with underscore
    |> String.replace(~r/[^a-z0-9_]+/, "_")
    # Collapse multiple underscores into one
    |> String.replace(~r/_+/, "_")
    # Remove leading/trailing underscores
    |> String.trim("_")
  end
end
