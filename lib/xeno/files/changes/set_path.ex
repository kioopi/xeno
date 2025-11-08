defmodule Xeno.Files.Changes.SetPath do
  use Ash.Resource.Change
  alias Xeno.Files.Directory

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :path) do
      nil ->
        changeset

      path ->
        ltree = Directory.path_to_ltree(path)

        Ash.Changeset.force_change_attribute(changeset, :path_ltree, ltree)
        |> add_name_if_empty(Ash.Changeset.get_attribute(changeset, :name))
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}

    # This seemed to be the atomic version, but
    # "Type `AshPostgres.Ltree` does not support atomic updates with expressions"
    # {:atomic,
    #   %{
    #     path_ltree: expr(fragment("replace(ltree2text(?), '/', '.')", ^path))
    #   }}
  end

  defp add_name_if_empty(changeset, nil) do
    [filename | _path] = Ash.Changeset.get_attribute(changeset, :path_ltree) |> Enum.reverse()

    Ash.Changeset.force_change_attribute(
      changeset,
      :name,
      humanize(filename)
    )
  end

  defp add_name_if_empty(changeset, name) do
    if String.trim(name) == "" do
      add_name_if_empty(changeset, nil)
    else
      changeset
    end
  end

  defp humanize(filename) do
    filename
    # Replace underscores with spaces
    |> String.replace("_", " ")
    # Capitalize each word
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
