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
  Generates JSON metadata from note (NEW FORMAT).

  Returns a map containing user-editable fields and system metadata:
  - _schema_version: Version of the JSON schema (currently "1.0")
  - _id: Note UUID (prefixed with _ to indicate system field)
  - _note: Message about system fields
  - name: Human-readable name (user-editable)
  - tags: Array of tags (user-editable)
  - data: Custom JSON data (user-editable)

  System fields excluded from JSON (stored in IndexedDB instead):
  - version (optimistic locking)
  - note_type_id (internal system concern)
  - inserted_at, updated_at (not user-editable)

  ## Examples

      iex> to_json_metadata(note)
      %{
        "_schema_version" => "1.0",
        "_id" => "...",
        "_note" => "Fields prefixed with _ are system-generated...",
        "name" => "My Note",
        "tags" => ["tag1"],
        "data" => %{}
      }
  """
  def to_json_metadata(note) do
    %{
      "_schema_version" => "1.0",
      "_id" => note.id,
      "_note" =>
        "Fields prefixed with _ are system-generated. Do not edit unless you know what you're doing.",
      "name" => note.name,
      "tags" => note.tags || [],
      "data" => note.data || %{}
    }
  end
end
