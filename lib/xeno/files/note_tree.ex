defmodule Xeno.Files.NoteTree do
  @moduledoc """
  Builds a directory tree that only includes branches containing notes.

  Reuses the existing directory tree builder while enriching each directory
  with its notes. Empty branches are pruned to keep the structure focused on
  actual content.
  """
  alias Xeno.Files.Directory
  alias Xeno.Files.Directory.Tree

  require Ash.Query

  @doc """
  Returns a pruned directory tree with notes attached to each directory.

  Each node is a tuple `{directory, children}` where `directory.notes` holds
  the list of notes in that directory.
  """
  def build do
    # TODO: find a way to express that filter more ASHdiomatic
    directories =
      Directory
      |> Ash.Query.sort(:path_ltree)
      |> Ash.Query.load([:depth, :parent, :filename, :path, :notes])
      |> Ash.Query.filter(
        fragment(
          "? @> (
            select path_ltree
            from directories
            where exists (
              select 1 from notes
              where notes.directory_id = directories.id
            )
          )",
          path_ltree
        )
      )
      |> Ash.read!()

    directories
    |> Tree.build_from_list(& &1)
  end
end
