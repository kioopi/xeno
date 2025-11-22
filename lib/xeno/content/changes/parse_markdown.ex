defmodule Xeno.Content.Changes.ParseMarkdown do
  @moduledoc """
  Parses markdown content from the :markdown_content argument
  and sets it as the :text attribute.

  Currently a passthrough. Future enhancement: extract frontmatter.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :markdown_content) do
      nil ->
        changeset

      markdown when is_binary(markdown) ->
        Ash.Changeset.force_change_attribute(changeset, :text, markdown)

      _ ->
        Ash.Changeset.add_error(changeset,
          field: :markdown_content,
          message: "markdown_content must be a string"
        )
    end
  end
end
