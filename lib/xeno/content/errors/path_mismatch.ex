defmodule Xeno.Content.Errors.PathMismatch do
  @moduledoc """
  Error for when a note ID exists but is located at a different path than expected.

  This indicates either:
  - The file was moved but the database wasn't updated
  - The file's metadata has an incorrect ID
  - Data corruption or inconsistency

  Fields:
  - note_id: The ID that was looked up
  - expected_path: Where the note is actually located in the database
  - actual_path: Where the file is located on the filesystem
  - note_name: Name of the note for context
  """
  use Splode.Error,
    fields: [:note_id, :expected_path, :actual_path, :note_name],
    class: :invalid

  def message(%__MODULE__{} = error) do
    "Path mismatch for note '#{error.note_name}' (#{error.note_id}): " <>
      "expected at '#{error.expected_path}' but file is at '#{error.actual_path}'. " <>
      "Either update the note's location in the database or fix the file's metadata."
  end
end
