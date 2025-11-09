defmodule Xeno.Files.Directory.NewPath do
  @moduledoc """
  Calculates new ltree paths for directories when their parent directory is moved.

  This calculation is used by the `MoveDescendants` change to efficiently compute
  updated paths for all descendants of a moved directory in a single database query.

  ## How it works

  When a directory is moved from one location to another, all of its descendants need
  their paths updated to reflect the new parent path. This module calculates the new
  path by:

  1. Taking the directory's current path (e.g., `["old_parent", "child", "grandchild"]`)
  2. Removing the old parent prefix (e.g., `["old_parent"]`)
  3. Prepending the new parent path (e.g., `["new_parent"]`)
  4. Resulting in the updated path (e.g., `["new_parent", "child", "grandchild"]`)

  The calculation is performed using PostgreSQL's ltree operators for efficiency:
  - `new_parent_path || subpath(current_path, nlevel(prev_parent_path))`

  ## Example

      # Moving "docs/guides" to "reference/guides"
      # All descendants like "docs/guides/tutorial" become "reference/guides/tutorial"

      query
      |> NewPath.add_calculation(
        ["reference"],  # new_parent_path
        ["docs"]        # prev_parent_path
      )
  """

  use Ash.Resource.Calculation
  require Ash.Query

  @impl true
  @doc """
  Generates the PostgreSQL ltree expression to calculate new paths.

  Uses the ltree `||` concatenation operator and `subpath` function to replace
  the old parent path prefix with the new parent path.

  ## Arguments

    * `args[:new_parent_path]` - The ltree path where the directory is being moved to
    * `args[:prev_parent_path]` - The original parent ltree path being replaced
  """
  def expression(_opts, %{arguments: args}) do
    {:ok, new_parent_path} = AshPostgres.Ltree.dump_to_native(args[:new_parent_path], nil)
    {:ok, prev_parent_path} = AshPostgres.Ltree.dump_to_native(args[:prev_parent_path], nil)

    expr(
      fragment(
        "(?::ltree || subpath(?, nlevel(?::ltree)))",
        ^new_parent_path,
        path_ltree,
        ^prev_parent_path
      )
    )
  end

  @doc """
  Adds the new_path calculation to a query for computing updated paths.

  The calculated value can be retrieved from `directory.calculations.new_path`
  after the query is executed.

  ## Parameters

    * `query` - An Ash query for Directory records
    * `new_parent_path` - The ltree path where directories are being moved to
    * `prev_parent_path` - The original parent ltree path being replaced

  ## Returns

  The query with the `:new_path` calculation added.

  ## Example

      Directory
      |> Ash.Query.for_read(:descendants_of, %{parent: moved_dir})
      |> NewPath.add_calculation(new_ltree, prev_ltree)
      |> Ash.read!()
      # Each directory will have calculations.new_path set
  """
  def add_calculation(query, new_parent_path, prev_parent_path) do
    query
    |> Ash.Query.calculate(
      :new_path,
      AshPostgres.Ltree,
      {__MODULE__, []},
      %{
        new_parent_path: new_parent_path,
        prev_parent_path: prev_parent_path
      }
    )
  end
end
