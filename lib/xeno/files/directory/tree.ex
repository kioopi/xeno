defmodule Xeno.Files.Directory.Tree do
  @moduledoc """
  Builds a nested tree structure from Directory records using their ltree paths.

  The tree is represented as a list of tuples where each tuple contains:
  - The directory record
  - A list of child directory tuples (same format, recursively)

  Example output: [{dir1, [{dir11, []}]}, {dir2, []}]
  """

  def build(query \\ Xeno.Files.Directory) do
    # Load directories sorted by path (parents before children) with filename
    dirs =
      query
      |> Ash.Query.sort(:path)
      |> Ash.Query.load([:depth, :parent])
      |> Ash.read!()

    # Pass 1: Initialize map with all directories and empty children lists
    {tree_map, roots} = map_directories_by_path(dirs)

    # Pass 2: Populate children by iterating in reverse (deepest first)
    # This ensures each directory already has its children when added to parent
    assign_directories_to_parents(tree_map, dirs)
    # Extract and return root-level entries (path length == 1)
    |> root_directories_with_children(roots)
  end

  defp map_directories_by_path(directories) do
    {tree, roots} =
      Enum.reduce(directories, {%{}, []}, fn dir, {tree, roots} ->
        {Map.put(tree, dir.path, {dir, []}), collect_roots(roots, dir)}
      end)

    {tree, Enum.reverse(roots)}
  end

  defp collect_roots(roots, dir) when dir.depth == 1 do
    [dir.path | roots]
  end

  defp collect_roots(roots, _dir), do: roots

  defp assign_directories_to_parents(tree, directories) do
    directories
    |> Enum.reverse()
    |> Enum.reduce(tree, fn dir, acc ->
      append_to_parent(acc, get_in(dir.parent.path), dir.path)
    end)
  end

  defp root_directories_with_children(tree, roots) do
    Enum.map(roots, &Map.fetch!(tree, &1))
  end

  defp append_to_parent(tree, nil, _child_path), do: tree

  defp append_to_parent(tree, parent_path, child_path) do
    child_entry = Map.fetch!(tree, child_path)

    append_child(tree, parent_path, child_entry)
  end

  defp append_child(tree, path, child) do
    Map.update!(tree, path, fn {name, children} ->
      {name, [child | children]}
    end)
  end
end
