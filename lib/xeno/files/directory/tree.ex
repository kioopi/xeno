defmodule Xeno.Files.Directory.Tree do
  @moduledoc """
  Builds a nested tree structure from Directory records using their ltree paths.

  The algorithm makes two
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
      |> Ash.Query.sort(:path_ltree)
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

  @doc """
  Finds the root ancestor for a given directory.

  This function efficiently finds the root directory by using the ltree path
  structure instead of recursively traversing parent relationships. It extracts
  the first segment of the directory's ltree path and queries for that root,
  resulting in O(1) database queries regardless of nesting depth.

  ## Parameters

    * `directory` - A Directory struct (must have path_ltree loaded)

  ## Returns

  The root Directory struct for the given directory's tree.

  ## Examples

      # For a nested directory like "/docs/guides/intro"
      directory = Directory.by_path!("/docs/guides/intro")
      root = Directory.Tree.find_root_ancestor(directory)
      # Returns the Directory with path "/docs"

      # For a root directory
      root = Directory.by_path!("/docs")
      root = Directory.Tree.find_root_ancestor(root)
      # Returns itself (the Directory with path "/docs")

  ## Performance

  This function uses ltree path analysis for O(1) query complexity:
  - Traditional approach: O(depth) queries (traverse parent chain)
  - Ltree approach: O(1) queries (extract root segment, query once)

  For a directory nested 10 levels deep, this saves 9 database queries.
  """
  def find_root_ancestor(%Xeno.Files.Directory{path_ltree: path_ltree} = dir) do
    # Extract first segment of ltree path (the root)
    [root_segment | _] = path_ltree

    if length(path_ltree) == 1 do
      # Already at root, return self
      dir
    else
      # Query for directory with single-segment path (the root)
      # Uses existing by_path action which leverages ltree indexing
      Xeno.Files.Directory.by_path!("/#{root_segment}")
    end
  end

  @doc """
  Builds a tree branch for a single root directory and all its descendants.

  This function efficiently constructs a tree structure for a specific root
  directory by leveraging the ltree-optimized `descendants_of` query, then
  using the same two-pass algorithm as `build/0` to create the nested structure.

  ## Parameters

    * `root_id` - The ID of the root directory to build a branch for

  ## Returns

  A single tuple of `{directory, children}` representing the root and its
  complete subtree. Unlike `build/0` which returns a list of root tuples,
  this returns just one tuple for the specified root.

  ## Examples

      # Build a branch for a specific root
      root = Directory.by_path!("/docs")
      branch = Directory.Tree.build_branch(root.id)
      # Returns: {%Directory{path: "/docs"}, [{%Directory{path: "/docs/guides"}, [...]}]}

      # Root with no children
      root = Directory.by_path!("/empty")
      branch = Directory.Tree.build_branch(root.id)
      # Returns: {%Directory{path: "/empty"}, []}
  """
  def build_branch(root_id) when is_binary(root_id) do
    # Load root directory
    root =
      Xeno.Files.Directory.get!(
        root_id,
        load: [:depth, :parent]
      )

    # Build tree using same algorithm as build/0 but for this subset
    # Get all descendants. Descendants can be loaded via the relationship
    # in Directory with one query. But that is ordered in the wrong order
    # and i didnt find a way to specify order there, so we use a separate query.
    descendants =
      Xeno.Files.Directory.descendants_of!(root)
      |> Ash.load!([:depth, :parent])

    all_dirs = [root | descendants]

    # Pass 1: Initialize map with all directories and empty children lists
    {tree_map, _roots} = map_directories_by_path(all_dirs)

    # Pass 2: Populate children by iterating in reverse (deepest first)
    assign_directories_to_parents(tree_map, all_dirs)
    # Extract and return just the single root branch (not a list)
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
  defp map_directories_by_path(directories, fun \\ fn dir -> dir end) do
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
