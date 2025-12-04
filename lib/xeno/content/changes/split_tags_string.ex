defmodule Xeno.Content.Changes.SplitTagsString do
  @moduledoc """
  Accepts tags as either a list of strings or a space-separated string,
  and sets an attribute change on tags.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :tags) do
      :error ->
        changeset

      {:ok, tags} ->
        set_changed_tags(changeset, tags)
    end
  end

  defp set_changed_tags(changeset, tags) when is_binary(tags) do
    Ash.Changeset.force_change_attribute(changeset, :tags, String.split(tags, " ", trim: true))
  end

  defp set_changed_tags(changeset, tags) when is_list(tags) do
    Ash.Changeset.force_change_attribute(changeset, :tags, tags)
  end

  defp set_changed_tags(changeset, nil) do
    Ash.Changeset.force_change_attribute(changeset, :tags, [])
  end

  defp set_changed_tags(changeset, _tags) do
    changeset
  end
end
