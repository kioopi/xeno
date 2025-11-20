defmodule Xeno.Files.Directory.Tree do
  @moduledoc """
  Tree-building utilities for Directory records using their ltree paths.

  This module provides functions to build nested tree structures from flat
  lists of directories, and to manipulate those tree structures efficiently.

  ## Tree Structure

  The tree is represented as a list of tuples where each tuple contains:
  - A transformed directory value (by default, the directory record itself)
  - A list of child directory tuples (same format, recursively)

  ## Usage

  Most users should interact with the directory tree through the Ash domain actions:

      # Build complete tree via domain function
      tree = Xeno.Files.tree!()

      # Build tree with transformation
      tree = Xeno.Files.tree!(%{transform: &(&1.filename)})

      # Build specific branch
      branch = Xeno.Files.branch!(root_id)

      # Update tree with new branch
      updated_tree = Directory.Tree.update_tree(tree, root_id, new_branch)

      # Get root ancestor via relationship
      directory_with_root = Ash.load!(directory, :root_ancestor)
      root = directory_with_root.root_ancestor

  The functions in this module are primarily used internally by Ash actions and
  for in-memory tree operations like `update_tree/3`.

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

      # Build a tree from a list of directories
      dirs = [root, child1, child2, grandchild]
      tree = Directory.Tree.build_from_list(dirs)
      # Returns: [{%Directory{}, [{%Directory{}, []}]}]

      # Build with transformation
      tree = Directory.Tree.build_from_list(dirs, &(&1.filename))
      # Returns: [{"root", [{"child", []}]}]
  """

  @doc """
  Builds a nested tree structure from a pre-loaded list of directories.

  This is a pure function that takes a list of directories and builds a tree
  structure without any database queries. Useful for building trees within
  Ash actions or other contexts where directories are already loaded.

  ## Parameters

    * `directories` - A list of Directory structs (must have depth and parent loaded)
    * `fun` - Optional transformation function (default: identity)

  ## Returns

  A list of root-level directory tuples, where each tuple is `{transformed_value, children}`.

  ## Examples

      # Build tree from loaded directories
      dirs = [root, child1, child2]
      tree = Directory.Tree.build_from_list(dirs)

      # With transformation
      tree = Directory.Tree.build_from_list(dirs, &(&1.filename))
  """
  def build_from_list(directories, fun \\ fn dir -> dir end) do
    {tree_map, roots} = map_directories_by_path(directories, fun)

    assign_directories_to_parents(tree_map, directories)
    |> root_directories_with_children(roots)
  end

  @doc """
  Builds a branch from a pre-loaded root directory and its descendants.

  Similar to `build_from_list/2` but returns a single branch tuple instead
  of a list of roots.

  ## Parameters

    * `root` - The root Directory struct
    * `descendants` - List of descendant Directory structs
    * `fun` - Optional transformation function (default: identity)

  ## Returns

  A single tuple of `{directory, children}`.
  """
  def build_branch_from_list(root, descendants, fun \\ fn dir -> dir end) do
    all_dirs = [root | descendants]
    {tree_map, _roots} = map_directories_by_path(all_dirs, fun)

    assign_directories_to_parents(tree_map, all_dirs)
    |> Map.fetch!(root.path)
  end

  @doc """
  Updates a tree by replacing or adding a branch for a specific root.

  This pure function takes an existing tree and updates it with a new branch
  for a given root directory. If the root exists in the tree, its branch is
  replaced. If not, the new branch is appended.

  ## Parameters

    * `tree` - The existing tree (list of root tuples)
    * `root_id` - The ID of the root directory to update
    * `new_branch` - The new branch tuple `{directory, children}` to insert

  ## Returns

  An updated tree with the new branch inserted or replaced. Unchanged branches
  remain untouched (same object references), making this efficient for LiveView
  updates where only affected branches need to re-render.

  ## Examples

      # Replace an existing branch
      tree = Directory.Tree.build(Directory)
      root = Directory.by_path!("/docs")
      new_branch = Directory.Tree.build_branch(root.id)
      updated_tree = Directory.Tree.update_tree(tree, root.id, new_branch)

      # Add a new branch
      tree = Directory.Tree.build(Directory)
      new_root = Directory.create!("/new")
      new_branch = Directory.Tree.build_branch(new_root.id)
      updated_tree = Directory.Tree.update_tree(tree, new_root.id, new_branch)
      # Tree now contains the original roots plus the new one

  ## Performance

  This is a pure Elixir function with O(n) complexity where n is the number of
  roots in the tree. Unchanged branches are not modified, preserving object
  identity for efficient change detection in Phoenix LiveView.
  """
  def update_tree(tree, root_id, new_branch) do
    case Enum.find_index(tree, fn {dir, _children} -> dir.id == root_id end) do
      nil ->
        # Root not in tree, append it
        tree ++ [new_branch]

      index ->
        # Replace at index
        List.replace_at(tree, index, new_branch)
    end
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
