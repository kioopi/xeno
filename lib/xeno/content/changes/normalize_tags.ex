defmodule Xeno.Content.Changes.NormalizeTags do
  @moduledoc """
  Normalizes tags by:
  - Trimming whitespace
  - Converting to lowercase for case-insensitivity
  - Removing duplicates

  This ensures consistent tag handling across the system.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :tags) do
      case Ash.Changeset.get_attribute(changeset, :tags) do
        nil ->
          changeset

        tags when is_list(tags) ->
          Ash.Changeset.force_change_attribute(changeset, :tags, normalize_tags(tags))

        _ ->
          changeset
      end
    else
      changeset
    end
  end

  defp normalize_tags(tags) do
    tags
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end
end
