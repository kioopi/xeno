defmodule Xeno.Content.IdResolver do
  @moduledoc """
  Resolves note IDs with fallback to file path lookup.

  Used by the import_from_filesystem action to handle cases where:
  - The provided ID exists and matches the path
  - The provided ID doesn't exist but a note exists at the path (ID mismatch)
  - Neither ID nor path resolve to a note

  Returns either the resolved note or a helpful error with suggestions.
  """

  alias Xeno.Content.Note
  alias Xeno.Content.Errors.NoteNotFound

  @doc """
  Resolves a note by ID with optional path verification.

  Returns:
  - `{:ok, note}` if the note is found
  - `{:error, NoteNotFound.t()}` with suggestion data if not found
  """
  def resolve(id, path) do
    case Note.get(id) do
      {:ok, note} ->
        verify_path_matches(note, path)

      {:error, _} ->
        suggest_by_path(id, path)
    end
  end

  defp verify_path_matches(note, nil) do
    {:ok, note}
  end

  defp verify_path_matches(note, path) when is_binary(path) do
    note = Ash.load!(note, :file_path)

    if note.file_path == path do
      {:ok, note}
    else
      {:path_mismatch, note, path}
    end
  end

  defp suggest_by_path(provided_id, path) when is_binary(path) do
    case Note.by_file_path(path) do
      {:ok, found_note} ->
        {:error,
         NoteNotFound.exception(
           provided_id: provided_id,
           suggested_id: found_note.id,
           file_path: path,
           note_name: found_note.name
         )}

      {:error, _} ->
        {:error,
         NoteNotFound.exception(
           provided_id: provided_id,
           suggested_id: nil,
           file_path: path,
           note_name: nil
         )}
    end
  end

  defp suggest_by_path(provided_id, _path) do
    {:error,
     NoteNotFound.exception(
       provided_id: provided_id,
       suggested_id: nil,
       file_path: nil,
       note_name: nil
     )}
  end
end
