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
    Ash.Changeset.update_change(changeset, :tags, &normalize_tags/1)
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
