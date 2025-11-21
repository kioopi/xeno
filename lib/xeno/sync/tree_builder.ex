defmodule Xeno.Sync.TreeBuilder do
  @moduledoc """
  Builds a hierarchical tree structure from directories and notes.

  Used to generate the file system structure that mirrors
  the database directory hierarchy.
  """

  @doc """
  Builds complete tree with all directories and their notes.

  Returns a list of {note, path} tuples where path is the relative
  file path without extension (e.g., "projects/web_app/architecture").

  ## Examples

      iex> build_sync_tree()
      [
        {%Note{name: "Architecture"}, "projects/web_app/architecture"},
        {%Note{name: "TODO"}, "projects/web_app/todo"}
      ]
  """
  def build_sync_tree do
    Xeno.Content.Note
    |> Ash.Query.load(:directory)
    |> Ash.read!()
    |> Enum.map(fn note ->
      path = note_file_path(note)
      {note, path}
    end)
  end

  @doc """
  Converts directory record to relative path.

  Uses the directory's path calculation which joins the ltree segments
  with forward slashes.

  ## Examples

      iex> directory_to_path(%Directory{path: "projects/web_app"})
      "projects/web_app"

      iex> directory_to_path(%Directory{path: "notes"})
      "notes"
  """
  def directory_to_path(directory) do
    directory.path
  end

  @doc """
  Determines file path for a note based on its directory.

  Returns the relative path without the .md extension.

  ## Examples

      iex> note_file_path(note)
      "projects/web_app/architecture"
  """
  def note_file_path(note) do
    dir_path = directory_to_path(note.directory)
    base_filename = String.replace_suffix(note.filename, ".md", "")

    Path.join(dir_path, base_filename)
  end
end
