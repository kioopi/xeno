defmodule Xeno.Files.Directory.RecursiveCreate do
  @moduledoc """
  Handles recursive creation of Directory records from relative path strings.

  This module is used by the `create_from_filesystem` action to create Directory
  records in the database that mirror a filesystem hierarchy. It processes a list
  of relative paths (e.g., `["parent", "parent/child"]`) and creates corresponding
  Directory records while maintaining parent-child relationships.

  ## How it works

  1. Takes a list of relative paths sorted by depth (shallowest first)
  2. For each path, splits it into segments (e.g., `"parent/child"` → `["parent", "child"]`)
  3. Recursively creates or retrieves each directory segment, passing the parent_id
     from one level to the next
  4. Uses the existing `Directory.get_or_create/2` function to handle upserts,
     ensuring no duplicates are created

  ## Example

      paths = ["grandparent", "grandparent/parent", "grandparent/parent/child"]
      {:ok, directories} = RecursiveCreate.create_directories(paths)
      # Returns list of 3 Directory records with proper parent_id relationships

  This module is typically called from within the `create_from_filesystem` generic
  action after the filesystem has been scanned by the `SubdirsOf` preparation.
  """

  alias Xeno.Files.Directory

  @doc """
  Creates Directory records for a list of relative paths.

  Takes a list of relative path strings and creates corresponding Directory records
  in the database. Paths should be sorted by depth (shallowest first) to ensure
  parent directories are created before their children.

  ## Parameters

    * `directories` - List of relative path strings (e.g., `["dir1", "dir1/subdir"]`)

  ## Returns

    * `{:ok, directories}` - List of all created/found Directory records
    * `{:error, reason}` - Error message if creation fails

  ## Examples

      iex> RecursiveCreate.create_directories(["docs", "docs/guides"])
      {:ok, [%Directory{filename: "docs"}, %Directory{filename: "guides", parent_id: "..."}]}

      iex> RecursiveCreate.create_directories([])
      {:ok, []}
  """
  def create_directories(directories) do
    try do
      # Process each directory, creating or retrieving it
      directories =
        Enum.reduce(directories, [], fn relative_path, acc ->
          case create_directory_chain(relative_path) do
            {:ok, directory} -> [directory | acc]
            {:error, _} -> acc
          end
        end)
        |> Enum.reverse()

      {:ok, directories}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # Creates a directory chain from a relative path string.
  #
  # Takes a path like "grandparent/parent/child" and splits it into segments,
  # then recursively creates each directory, passing the parent_id from level to level.
  defp create_directory_chain(relative_path) do
    segments = String.split(relative_path, "/")
    create_directory_segments(segments, nil)
  end

  # Recursively creates directory records from path segments, maintaining parent-child relationships.
  #
  # Base case: empty list returns error
  defp create_directory_segments([], _parent_id), do: {:error, "Empty path"}

  # Base case: single segment creates final directory with given parent
  defp create_directory_segments([segment], parent_id) do
    Directory.get_or_create(segment, parent_id)
  end

  # Recursive case: create/get first segment, then process remaining segments with its ID as parent
  defp create_directory_segments([segment | rest], parent_id) do
    case Directory.get_or_create(segment, parent_id) do
      {:ok, directory} -> create_directory_segments(rest, directory.id)
      error -> error
    end
  end
end
