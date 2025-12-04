defmodule Xeno.Content.Calculations.NoteParams do
  @moduledoc """
  Returns the inital_* attributes from the NoteType as a map of params.

  To be used in Changesets when creating a new Note from a NoteType
  or changing its NoteType.
  """
  use Ash.Resource.Calculation

  @impl true
  def calculate(note_types, _opts, _context) do
    Enum.map(note_types, fn note_type ->
      params(note_type)
    end)
  end

  defp params_names() do
    [tags: :initial_tags, text: :initial_text, data: :initial_data]
  end

  def params(note_type) do
    Enum.reduce(params_names(), %{}, fn {param, attr}, acc ->
      case Map.get(note_type, attr) do
        nil -> acc
        value -> Map.put(acc, to_string(param), value)
      end
    end)
  end
end
