defmodule Xeno.Files.Directory.SubdirsOf do
  @moduledoc """
  An Ash preparation that scans a filesystem path and collects all subdirectories.

  This preparation is used in the `create_from_filesystem` action to scan a
  filesystem directory and collect all its subdirectories recursively. The collected
  paths are then stored in the action context for use by the action's run function.

  ## How it works in the action pipeline

  1. **Initialization**: Validates that an argument name (as atom) is provided
  2. **Preparation**: Retrieves the path from the specified argument
  3. **Scanning**: Recursively walks the filesystem collecting subdirectories
  4. **Sorting**: Orders paths by depth (shallowest first) for proper parent creation
  5. **Context**: Stores the sorted list in `context.directories` for the run function

  ## Usage

  In an Ash action definition:

      action :create_from_filesystem do
        argument :path, :string
        prepare {Xeno.Files.Directory.SubdirsOf, arg: :path}

        run fn _input, context ->
          # Access collected directories via context.source_context.directories
          directories = context.source_context.directories
          # ...
        end
      end

  ## Example

  Given a filesystem structure:
  ```
  /base/
    grandparent/
      parent/
        child/
  ```

  When called with `/base/` as the path argument, this preparation will collect:
  `["grandparent", "grandparent/parent", "grandparent/parent/child"]`

  These paths are relative to the base path and sorted by depth.
  """

  use Ash.Resource.Preparation

  @doc """
  Initializes the preparation by validating the options.

  Ensures that the `arg` option is provided and is an atom, which should be the
  name of the action argument containing the filesystem path to scan.

  ## Parameters

    * `opts` - Keyword list that must contain `:arg` as an atom

  ## Returns

    * `{:ok, opts}` - If validation passes
    * `{:error, message}` - If `:arg` is missing or not an atom
  """
  @impl true
  def init(opts) do
    if opts[:arg] != nil && is_atom(opts[:arg]) do
      {:ok, opts}
    else
      {:error, "arg must be an atom!"}
    end
  end

  @doc """
  Declares what action types this preparation supports.

  This preparation only works with `Ash.ActionInput`, making it suitable for
  generic actions that use ActionInput rather than changesets or queries.
  """
  @impl true
  def supports(_opts), do: [Ash.ActionInput]

  @doc """
  Prepares the action input by scanning the filesystem and storing results in context.

  Retrieves the path from the specified argument, scans it for subdirectories,
  sorts them by depth, and stores the result in the action context under the
  `:directories` key.

  ## Parameters

    * `input` - The `Ash.ActionInput` struct containing the action arguments
    * `opts` - Options with `:arg` specifying which argument contains the path
    * `_context` - The action context (unused)

  ## Returns

  An updated `Ash.ActionInput` with subdirectories stored in context.
  """
  @impl true
  def prepare(input, opts, _context) do
    Ash.ActionInput.get_argument(input, opts[:arg])
    |> subdirs_of()
    |> then(fn subdirs ->
      Ash.ActionInput.set_context(input, %{directories: subdirs})
    end)
  end

  @doc """
  Scans a filesystem path and returns all subdirectories sorted by depth.

  Takes a filesystem path and recursively collects all subdirectories,
  returning them as relative paths sorted by depth (shallowest first).

  ## Parameters

    * `path` - Absolute filesystem path to scan

  ## Returns

  List of relative path strings sorted by depth.

  ## Examples

      iex> SubdirsOf.subdirs_of("/tmp/test")
      ["dir1", "dir2", "dir1/subdir", "dir2/subdir"]
  """
  def subdirs_of(path) do
    collect_subdirectories(path)
    # Sort by depth to ensure parents are created first
    |> Enum.sort_by(&depth/1)
  end

  # Calculates the depth of a path by counting path segments.
  #
  # Used for sorting paths so that parent directories come before children.
  # Examples: "parent" = 1, "parent/child" = 2, "parent/child/grandchild" = 3
  defp depth(path), do: path |> String.split("/") |> length()

  # Recursively collects all subdirectories from a base path.
  #
  # Walks the filesystem tree depth-first, building a list of relative paths
  # for all subdirectories found. The `walked_path` accumulates the relative
  # path from the base as we recurse deeper.
  #
  # Parameters:
  #   - base_path: The root directory to start scanning from
  #   - walked_path: The current relative path from base (starts as "")
  #
  # Returns a flat list of relative path strings (e.g., ["dir", "dir/subdir"])
  defp collect_subdirectories(base_path, walked_path \\ "")

  defp collect_subdirectories(base_path, walked_path) do
    current_path = Path.join(base_path, walked_path)

    # Helper to check if an entry is a directory
    is_dir? = fn dir -> Path.join(current_path, dir) |> File.dir?() end

    case File.ls(current_path) do
      {:ok, files} ->
        files
        |> Enum.filter(is_dir?)
        |> Enum.flat_map(fn dir ->
          # Build the relative path for this subdirectory
          next = Path.join(walked_path, dir)
          # Include this directory and recursively collect its subdirectories
          [next | collect_subdirectories(base_path, next)]
        end)

      {:error, _} ->
        []
    end
  end
end
