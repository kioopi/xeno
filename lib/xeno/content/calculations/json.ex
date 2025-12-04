defmodule Xeno.Content.Calculations.Json do
  @moduledoc """
  Converts markdown text to HTML using Earmark.

  Handles edge cases like nil/empty text. Earmark escapes HTML tags
  by default for security, preventing XSS attacks.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:data]
  end

  @impl true
  def calculate(notes, _opts, _context) do
    Enum.map(notes, fn note -> json_string(note.data) end)
  end

  def json_string(nil), do: "{}"
  def json_string(""), do: "{}"

  def json_string(data) when is_binary(data) do
    data
  end

  def json_string(data) do
    Jason.encode!(data, pretty: true)
  end
end
