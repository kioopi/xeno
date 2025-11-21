defmodule Xeno.Sync do
  @moduledoc """
  Public API for sync operations.

  Coordinates between export and import operations,
  handles batching, error recovery, and status reporting.
  """

  alias Xeno.Sync.{Exporter, TreeBuilder}
  alias Xeno.Content.Note

  @doc """
  Exports all notes for initial sync.

  Returns a list of {note, path} tuples where each tuple contains
  the note struct and its relative file path.

  ## Examples

      iex> export_all()
      [
        {%Note{name: "Architecture"}, "projects/web_app/architecture"},
        {%Note{name: "TODO"}, "projects/web_app/todo"}
      ]
  """
  def export_all do
    TreeBuilder.build_sync_tree()
  end

  @doc """
  Exports a single note for re-sync.

  Returns a tuple containing the markdown content and JSON metadata string.

  ## Examples

      iex> export_note(note_id)
      {:ok, {"# Note content", "{\\"id\\": \\"...\\"}"}}

      iex> export_note("non-existent-id")
      {:error, %Ash.Error.Query.NotFound{}}
  """
  def export_note(note_id) do
    case Note.get(note_id) do
      {:ok, note} ->
        Exporter.export_note(note)

      {:error, error} ->
        {:error, error}
    end
  end
end
