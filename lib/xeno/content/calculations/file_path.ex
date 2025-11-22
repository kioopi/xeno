defmodule Xeno.Content.Calculations.FilePath do
  @moduledoc """
  Calculates the file path for a note by combining directory path and filename.

  Returns the path without extension (e.g., "projects/work/meeting-notes").
  The filename is used as-is, so if it contains an extension, it will be preserved.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:directory]
  end

  @impl true
  def calculate(notes, _opts, _context) do
    Enum.map(notes, fn note ->
      if note.directory do
        Path.join(note.directory.path, note.filename)
      else
        {:error, "Directory must be loaded to calculate file_path"}
      end
    end)
  end
end
