defmodule Xeno.Files.Directory.RootPath do
  @moduledoc """
  Calculates the root path (ltree) for a directory.

  For a directory at path ["foo", "bar", "baz"], the root path is ["foo"].
  For a directory already at root (path ["foo"]), returns the path itself.
  """
  use Ash.Resource.Calculation
  require Ash.Query

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      [root_segment | _] = record.path_ltree
      [root_segment]
    end)
  end

  @impl true
  def expression(_opts, _context) do
    # Use PostgreSQL subpath function to get just the first element
    # subpath(path, 0, 1) returns elements from index 0 with length 1
    expr(fragment("subpath(?, 0, 1)", path_ltree))
  end
end
