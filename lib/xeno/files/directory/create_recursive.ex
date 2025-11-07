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
      directories = Enum.map(directories, &Directory.get_or_create!(&1))

      {:ok, directories}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
end
