defmodule Xeno.Content.Errors.NoteNotFound do
  @moduledoc """
  Custom error for when a note ID is not found during filesystem import.

  Includes optional suggestion data to help resolve ID mismatches:
  - suggested_id: ID of note found at the provided path
  - note_name: Name of the suggested note
  - file_path: File path where the mismatch occurred
  """
  use Splode.Error,
    fields: [:provided_id, :suggested_id, :file_path, :note_name],
    class: :invalid

  def message(%__MODULE__{suggested_id: nil, file_path: nil} = error) do
    "Note with ID '#{error.provided_id}' not found."
  end

  def message(%__MODULE__{suggested_id: nil} = error) do
    "Note with ID '#{error.provided_id}' not found. No existing note at path '#{error.file_path}'."
  end

  def message(%__MODULE__{} = error) do
    "Note with ID '#{error.provided_id}' not found at path '#{error.file_path}'. " <>
      "Found note '#{error.note_name}' with ID '#{error.suggested_id}' at that path."
  end
end
