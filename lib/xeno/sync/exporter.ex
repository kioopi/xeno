defmodule Xeno.Sync.Exporter do
  @moduledoc """
  Exports notes to file system structure.

  Generates markdown and JSON content from Note records,
  organizing them according to their directory hierarchy.
  """

  @doc """
  Exports a single note to markdown and JSON content.

  Returns a tuple containing the markdown content (from note.text)
  and the JSON metadata string.

  ## Examples

      iex> export_note(note)
      {:ok, {"# Note content", "{\\"id\\": \\"...\\"}"}}
  """
  def export_note(note) do
    markdown = to_markdown(note)
    metadata = to_json_metadata(note)

    case Jason.encode(metadata, pretty: true) do
      {:ok, json_string} -> {:ok, {markdown, json_string}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates markdown content from note text.

  Returns the note's text field as-is, or an empty string if text is nil.

  ## Examples

      iex> to_markdown(%{text: "# Hello"})
      "# Hello"

      iex> to_markdown(%{text: nil})
      ""
  """
  def to_markdown(note) do
    note.text || ""
  end

  @doc """
  Generates JSON metadata from note.

  Returns a map containing:
  - id: Note UUID
  - name: Human-readable name
  - note_type_id: UUID of the note type
  - tags: Array of tags
  - data: Custom JSON data
  - version: Optimistic lock version
  - inserted_at: Creation timestamp
  - updated_at: Last modification timestamp

  ## Examples

      iex> to_json_metadata(note)
      %{
        "id" => "...",
        "name" => "My Note",
        "note_type_id" => "...",
        "tags" => ["tag1"],
        "data" => %{},
        "version" => 1,
        "inserted_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }
  """
  def to_json_metadata(note) do
    %{
      "id" => note.id,
      "name" => note.name,
      "note_type_id" => note.note_type_id,
      "tags" => note.tags || [],
      "data" => note.data || %{},
      "version" => note.version,
      "inserted_at" => DateTime.to_iso8601(note.inserted_at),
      "updated_at" => DateTime.to_iso8601(note.updated_at)
    }
  end
end
