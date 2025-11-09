defmodule Xeno.Files.Changes.MoveDescendants do
  @moduledoc """
  Updates all descendant directory paths when a parent directory is moved.

  This change is automatically applied during the `:move` action to ensure that
  when a directory is moved to a new location, all of its descendants (children,
  grandchildren, etc.) have their paths updated to reflect the new hierarchy.

  ## How it works

  When a directory is moved from one path to another, this change:

  1. Captures the old path (before the move) and new path (after the move)
  2. Finds all descendants of the moved directory using the `:descendants_of` read action
  3. Calculates new paths for each descendant using the `NewPath` calculation
  4. Bulk updates all descendants using the `:parent_moved` action

  ## Example

  When moving "docs" to "reference/docs":

      # Before move
      docs/            (path: ["docs"])
      docs/guides/     (path: ["docs", "guides"])
      docs/api/        (path: ["docs", "api"])

      Directory.move!(docs_dir, path: "reference/docs")

      # After move
      reference/docs/         (path: ["reference", "docs"])
      reference/docs/guides/  (path: ["reference", "docs", "guides"])
      reference/docs/api/     (path: ["reference", "docs", "api"])

  All descendants are automatically updated in a single efficient database operation.

  ## Integration

  This change is used in the `:move` action and runs as a `before_action` hook,
  ensuring descendants are updated before the parent directory's path is committed.

  The bulk update uses atomic operations where possible for efficiency.
  """

  use Ash.Resource.Change
  require Ash.Query
  alias Xeno.Files.Directory

  @impl true
  @doc """
  Updates paths for all descendants when a directory is moved.

  This function runs before the directory move is committed, capturing both the
  old and new paths to calculate updated paths for all descendants.

  ## Process

  1. Retrieves the previous ltree path from the changeset's original data
  2. Retrieves the new ltree path from the changeset's pending changes
  3. Queries for all descendants using the `:descendants_of` read action
  4. Adds a calculation to compute each descendant's new path
  5. Bulk updates all descendants using the `:parent_moved` action

  ## Parameters

    * `changeset` - The changeset for the directory being moved
    * `_opts` - Options (currently unused)
    * `_context` - Context (currently unused)

  ## Returns

  The unmodified changeset (descendants are updated as a side effect).
  """
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      prev_ltree = Ash.Changeset.get_data(changeset, :path_ltree)
      new_ltree = Ash.Changeset.get_attribute(changeset, :path_ltree)

      Ash.Query.for_read(Directory, :descendants_of, %{parent: changeset.data})
      |> Directory.NewPath.add_calculation(new_ltree, prev_ltree)
      |> Ash.bulk_update!(
        :parent_moved,
        %{},
        strategy: [:atomic, :atomic_batches, :stream]
      )

      changeset
    end)
  end
end
