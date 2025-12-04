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
    directories =
      Directory
      |> Ash.Query.sort(:path_ltree)
      |> Ash.Query.load([:depth, :parent, :filename, :path, :notes])
      |> filter_directories_with_notes()
      |> Ash.read!()

    directories
    |> Tree.build_from_list()
  end

  def filter_directories_with_notes(query) do
    # TODO: find a way to express that filter more ASHdiomatic
    # TODO this needs tests
    Ash.Query.filter(
      query,
      fragment(
        "EXISTS (
          SELECT 1
          FROM directories AS child
          JOIN notes AS n ON n.directory_id = child.id
          WHERE child.path_ltree <@ ?
        )",
        path_ltree
      )
    )
  end
end
