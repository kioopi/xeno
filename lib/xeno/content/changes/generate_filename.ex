defmodule Xeno.Content.Changes.GenerateFilename do
  @moduledoc """
  Generates a filesystem-friendly filename from a human-readable name.

  Only runs when filename is not provided but name is.
  Transforms by:
  - Converting to lowercase
  - Replacing non-alphanumeric characters (except underscores) with underscores
  - Collapsing multiple consecutive underscores into single underscore
  - Adding .md extension
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :name) do
      nil ->
        changeset

      name when is_binary(name) ->
        filename = generate_filename(name)
        Ash.Changeset.force_change_attribute(changeset, :filename, filename)
    end
  end

  defp generate_filename(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]+/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
    |> Kernel.<>(".md")
  end
end
