defmodule Xeno.Files.Changes.SetPath do
  @moduledoc """
  Converts a filesystem path string to an ltree path and sets it on the Directory record.

  This change is used in both the `:create` and `:move` actions to handle path conversion
  and automatic name generation. It converts user-friendly filesystem paths (e.g., "docs/guides")
  into PostgreSQL ltree paths (e.g., `["docs", "guides"]`).

  ## Responsibilities

  1. Converts the `:path` argument from a string to an ltree array
  2. Sets the converted ltree as the `:path_ltree` attribute
  3. Auto-generates a human-friendly `:name` from the filename if not provided

  ## Usage

  This change is automatically applied on:
  - `:create` action - Creates a new directory at the specified path
  - `:move` action - Moves a directory to a new path

  ## Examples

      # Creating a directory
      Directory.create!("docs/guides")
      # Sets path_ltree: ["docs", "guides"]
      # Sets name: "Guides" (auto-generated from filename)

      # Creating with explicit name
      Directory.create!("docs/api_reference", name: "API Reference")
      # Sets path_ltree: ["docs", "api_reference"]
      # Sets name: "API Reference" (user-provided)

      # Moving a directory
      Directory.move!(directory, path: "reference/api")
      # Updates path_ltree: ["reference", "api"]
      # Name remains unchanged unless empty
  """

  use Ash.Resource.Change
  alias Xeno.Files.Directory

  @impl true
  @doc """
  Converts the path argument to ltree format and auto-generates name if needed.

  ## Process

  1. Checks if a `:path` argument exists
  2. Converts the string path to ltree using `Directory.path_to_ltree/1`
  3. Sets the ltree as the `:path_ltree` attribute
  4. If `:name` is empty or nil, generates a name from the last path segment

  ## Parameters

    * `changeset` - The Ash changeset being processed
    * `_opts` - Options (currently unused)
    * `_context` - Context (currently unused)

  ## Returns

  The modified changeset with `:path_ltree` and optionally `:name` set.
  """
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
  @doc """
  Atomic implementation that delegates to the non-atomic `change/3` function.

  Currently, this cannot be truly atomic because the `AshPostgres.Ltree` type
  does not support atomic updates with expressions. The commented code shows
  what an atomic implementation would look like if ltree supported it.

  ## Parameters

    * `changeset` - The Ash changeset being processed
    * `opts` - Options passed to the change
    * `context` - Context passed to the change

  ## Returns

  `{:ok, changeset}` with the path and name changes applied.
  """
  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}

    # This seemed to be the atomic version, but
    # "Type `AshPostgres.Ltree` does not support atomic updates with expressions"
    # {:atomic,
    #   %{
    #     path_ltree: expr(fragment("replace(ltree2text(?), '/', '.')", ^path))
    #   }}
  end

  # Generates a human-friendly name from the filename if the name is empty.
  #
  # Takes the last segment of the path (the filename) and converts it to a
  # display-friendly name by replacing underscores with spaces and capitalizing
  # each word.
  #
  # Examples:
  #   filename: "api_reference" -> "Api Reference"
  #   filename: "getting_started" -> "Getting Started"
  #   filename: "guides" -> "Guides"
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

  # Converts a filesystem-style filename to a human-friendly display name.
  #
  # Replaces underscores with spaces and capitalizes each word.
  #
  # Examples:
  #   humanize("api_reference") -> "Api Reference"
  #   humanize("user_guide") -> "User Guide"
  #   humanize("readme") -> "Readme"
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
