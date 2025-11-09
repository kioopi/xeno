defmodule Xeno.Files.Directory.Tree do
  @moduledoc """
  Builds a nested tree structure from Directory records using their ltree paths.

  This module provides efficient O(n) tree construction by leveraging PostgreSQL's
  ltree extension and Elixir's immutable data structures. The algorithm makes two
  passes over the directory list to build a complete hierarchical tree.

  ## Tree Structure

  The tree is represented as a list of tuples where each tuple contains:
  - A transformed directory value (by default, the directory record itself)
  - A list of child directory tuples (same format, recursively)

  ## Algorithm

  The two-pass algorithm works as follows:

  ### Pass 1: Initialization
  - Creates a map of all directories with empty children lists
  - Collects root-level directories (depth == 1)
  - Applies the transformation function to each directory value

  ### Pass 2: Population
  - Iterates directories in reverse (deepest first)
  - Adds each directory to its parent's children list
  - Ensures children are fully populated before being added to parents

  ## Performance

  - Time complexity: O(n) where n is the number of directories
  - Space complexity: O(n) for the intermediate map
  - Efficient for large directory hierarchies with thousands of entries

  ## Examples

      # Build a simple tree with full directory records
      tree = Directory.Tree.build(Directory)
      # Returns: [{%Directory{name: "docs"}, [{%Directory{name: "guides"}, []}]}]

      # Build a tree with custom transformation (e.g., just filenames)
      tree = Directory.Tree.build(Directory, fn dir -> dir.filename end)
      # Returns: [{"docs", [{"guides", []}]}]

      # Build a tree with custom data structure
      tree = Directory.Tree.build(Directory, fn dir ->
        %{id: dir.id, name: dir.name, path: dir.path}
      end)
  """

  @doc """
  Builds a nested tree structure from directories in the database.

  Takes a query (or the Directory module directly) and an optional transformation
  function to customize how directory data appears in the tree.

  ## Parameters

    * `query` - An Ash query or the Directory module (default: `Xeno.Files.Directory`)
    * `fun` - A function to transform each directory record (default: identity function)

  ## Returns

  A list of root-level directory tuples, where each tuple is `{transformed_value, children}`.

  ## Examples

      # Simple tree with full directory records
      Directory.Tree.build(Directory)

      # Tree with only filenames
      Directory.Tree.build(Directory, fn dir -> dir.filename end)
      # => [{"docs", [{"guides", []}, {"api", []}]}]

      # Tree with filtered directories
      query = Ash.Query.filter(Directory, parent_id == ^some_id)
      Directory.Tree.build(query, fn dir -> dir.name end)

      # Tree with custom struct
      Directory.Tree.build(Directory, fn dir ->
        %{id: dir.id, label: dir.name, type: "directory"}
      end)

  ## Implementation Details

  The function performs the following steps:

  1. Loads all directories sorted by path (ensuring parents come before children)
  2. Loads the `:depth` and `:parent` calculations for efficient processing
  3. Builds an intermediate map structure with all directories
  4. Populates children by iterating in reverse order
  5. Returns only root-level entries with their complete subtrees
  """
  def build(query \\ Xeno.Files.Directory, fun \\ fn dir -> dir end) do
    # Load directories sorted by path (parents before children) with filename
    dirs =
      query
      |> Ash.Query.sort(:path)
      |> Ash.Query.load([:depth, :parent])
      |> Ash.read!()

    # Pass 1: Initialize map with all directories and empty children lists
    {tree_map, roots} = map_directories_by_path(dirs, fun)

    # Pass 2: Populate children by iterating in reverse (deepest first)
    # This ensures each directory already has its children when added to parent
    assign_directories_to_parents(tree_map, dirs)
    # Extract and return root-level entries (path length == 1)
    |> root_directories_with_children(roots)
  end

  # Creates the initial tree map and collects root directory paths.
  #
  # Pass 1 of the algorithm: Iterates through all directories to:
  # 1. Build a map where keys are directory paths and values are {transformed_dir, []} tuples
  # 2. Collect paths of root-level directories (depth == 1) for final extraction
  #
  # The transformation function is applied here to each directory before storing.
  # Roots are collected in reverse order and then reversed again to maintain original order.
  #
  # Returns: {tree_map, root_paths}
  defp map_directories_by_path(directories, fun) do
    {tree, roots} =
      Enum.reduce(directories, {%{}, []}, fn dir, {tree, roots} ->
        {Map.put(tree, dir.path, {fun.(dir), []}), collect_roots(roots, dir)}
      end)

    {tree, Enum.reverse(roots)}
  end

  # Adds a directory's path to the roots list if it's a root-level directory.
  #
  # Root directories have depth == 1, meaning they're at the top level of the hierarchy.
  # Paths are prepended to the list (for efficiency), so they'll be reversed later.
  defp collect_roots(roots, dir) when dir.depth == 1 do
    [dir.path | roots]
  end

  defp collect_roots(roots, _dir), do: roots

  # Populates parent-child relationships in the tree.
  #
  # Pass 2 of the algorithm: Iterates directories in reverse order (deepest first)
  # and adds each directory to its parent's children list. This ensures that when
  # a directory is added to its parent, it already contains all of its own children.
  #
  # Uses the `:parent` relationship loaded from the database to find parent paths.
  defp assign_directories_to_parents(tree, directories) do
    directories
    |> Enum.reverse()
    |> Enum.reduce(tree, fn dir, acc ->
      append_to_parent(acc, get_in(dir.parent.path), dir.path)
    end)
  end

  # Extracts the final tree structure by fetching all root directory entries.
  #
  # Takes the fully-populated tree map and the list of root paths, then returns
  # only the root-level tuples. Each root tuple contains all of its descendants.
  defp root_directories_with_children(tree, roots) do
    Enum.map(roots, &Map.fetch!(tree, &1))
  end

  # Appends a directory to its parent's children list.
  #
  # If parent_path is nil, the directory is a root (no parent), so no action needed.
  # Otherwise, fetches the child entry from the tree and adds it to the parent.
  defp append_to_parent(tree, nil, _child_path), do: tree

  defp append_to_parent(tree, parent_path, child_path) do
    child_entry = Map.fetch!(tree, child_path)

    append_child(tree, parent_path, child_entry)
  end

  # Updates a parent directory's children list by prepending a new child.
  #
  # Children are prepended (not appended) for efficiency. Since we iterate in
  # reverse order (deepest first), this naturally results in the correct order
  # when siblings are at the same depth level.
  defp append_child(tree, path, child) do
    Map.update!(tree, path, fn {dir, children} ->
      {dir, [child | children]}
    end)
  end
end
