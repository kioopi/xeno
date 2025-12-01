defmodule Xeno.Content.Calculations.Html do
  @moduledoc """
  Converts markdown text to HTML using Earmark.

  Handles edge cases like nil/empty text. Earmark escapes HTML tags
  by default for security, preventing XSS attacks.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:text]
  end

  @impl true
  def calculate(notes, _opts, _context) do
    Enum.map(notes, fn note ->
      case note.text do
        nil ->
          nil

        "" ->
          ""

        text when is_binary(text) ->
          case Earmark.as_html(text) do
            {:ok, html, _warnings} -> html
            {:error, _html, _errors} -> text
          end
      end
    end)
  end
end
