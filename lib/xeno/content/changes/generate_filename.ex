defmodule Xeno.Content.Changes.GenerateFilename do
  @moduledoc """
  Generates a filesystem-friendly filename from a human-readable name.

  Only runs when filename is not provided but name is.
  Transforms by:
  - Converting to lowercase
  - Replacing non-alphanumeric characters (except underscores) with underscores
  - Collapsing multiple consecutive underscores into single underscore

  Note: Does not add any file extension. Extensions are added during export.
  """

  use Ash.Resource.Change
  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    case Changeset.fetch_change(changeset, :name) do
      :error ->
        changeset

      {:ok, ""} ->
        changeset

      {:ok, name} when is_binary(name) ->
        filename = generate_filename(name)
        Changeset.force_change_attribute(changeset, :filename, filename)

      {:ok, _} ->
        changeset
    end
  end

  # TODO: this should be a calculation
  defp generate_filename(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.replace(~r/-+/, "-")
    |> String.trim("_")
    |> String.trim("-")
  end
end
