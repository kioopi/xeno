defmodule Xeno.Sync.Importer do
  @moduledoc """
  Imports file changes from the local file system into the database.

  Parses markdown and JSON content, validates data,
  and updates Note records using the standard update action.
  """

  @doc """
  Parses markdown content and returns the text.

  Currently a passthrough that returns the content as-is.
  Future enhancement: Extract frontmatter if present.

  ## Examples

      iex> parse_markdown("# Hello\\n\\nWorld")
      {:ok, "# Hello\\n\\nWorld"}

      iex> parse_markdown("")
      {:ok, ""}

      iex> parse_markdown(nil)
      {:ok, ""}
  """
  def parse_markdown(nil), do: {:ok, ""}
  def parse_markdown(content) when is_binary(content), do: {:ok, content}

  @doc """
  Parses JSON metadata string and returns a map.

  ## Examples

      iex> parse_metadata(~s({"id": "123", "version": 1}))
      {:ok, %{"id" => "123", "version" => 1}}

      iex> parse_metadata("{invalid")
      {:error, %Jason.DecodeError{}}
  """
  def parse_metadata(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Validates that metadata contains all required fields.

  Required fields:
  - id: Must be a valid UUID string
  - version: Must be present (for optimistic locking)

  ## Examples

      iex> validate_metadata(%{"id" => "550e8400-e29b-41d4-a716-446655440000", "version" => 1})
      :ok

      iex> validate_metadata(%{"version" => 1})
      {:error, "Missing required field: id"}

      iex> validate_metadata(%{"id" => "invalid", "version" => 1})
      {:error, "Invalid UUID format for id"}
  """
  def validate_metadata(metadata) when is_map(metadata) do
    with :ok <- validate_required_field(metadata, "id"),
         :ok <- validate_required_field(metadata, "version"),
         :ok <- validate_uuid_format(metadata["id"]) do
      :ok
    end
  end

  defp validate_required_field(metadata, field) do
    if Map.has_key?(metadata, field) do
      :ok
    else
      {:error, "Missing required field: #{field}"}
    end
  end

  defp validate_uuid_format(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, "Invalid UUID format for id"}
    end
  end

  @doc """
  Parses a note path into directory path and filename components.

  Paths are in the format: "directory/path/filename"
  - Single directory: "docs/note" -> {"docs", "note"}
  - Nested notes: "projects/work/note" -> {"projects/work", "note"}

  ## Examples

      iex> parse_note_path("projects/work/meeting-notes")
      {:ok, "projects/work", "meeting-notes"}

      iex> parse_note_path("docs/readme")
      {:ok, "docs", "readme"}

      iex> parse_note_path("")
      {:error, :invalid_path}
  """
  def parse_note_path(path) when is_binary(path) and path != "" do
    path = String.trim(path)

    if String.ends_with?(path, "/") do
      {:error, :invalid_path}
    else
      parts = String.split(path, "/")

      case parts do
        [] ->
          {:error, :invalid_path}

        [_single_part] ->
          {:error, :invalid_path}

        parts ->
          filename = List.last(parts)
          directory_path = parts |> Enum.drop(-1) |> Enum.join("/")
          {:ok, directory_path, filename}
      end
    end
  end

  def parse_note_path(_), do: {:error, :invalid_path}

  @doc """
  Finds a note by its file system path.

  Uses the Note.by_file_path action to look up notes by their full path.

  ## Examples

      iex> find_note_by_path("projects/work/meeting-notes")
      {:ok, %Xeno.Content.Note{}}

      iex> find_note_by_path("nonexistent/path")
      {:error, :not_found}
  """
  def find_note_by_path(path) do
    case Xeno.Content.Note.by_file_path(path) do
      {:ok, note} ->
        {:ok, note}

      {:error, error} ->
        if Exception.message(error) =~ "Invalid file path" do
          {:error, :invalid_path}
        else
          {:error, :not_found}
        end
    end
  end

  @doc """
  Processes a file change from the file system and updates the database.

  Accepts a map with the following keys:
  - `note_id`: UUID of the note to update
  - `path`: File system path (optional, used for ID suggestion)
  - `markdown_content`: Updated text content from the .md file
  - `metadata`: Map containing id, version, and optional fields (name, tags, data)

  Returns:
  - `{:ok, updated_note}` on success
  - `{:error, reason}` on validation failure or version conflict
  - `{:error, %{type: :id_not_found, ...}}` when ID is wrong but path-based suggestion available

  ## Examples

      iex> import_change(%{
      ...>   "note_id" => "550e8400-e29b-41d4-a716-446655440000",
      ...>   "markdown_content" => "# Updated content",
      ...>   "metadata" => %{
      ...>     "id" => "550e8400-e29b-41d4-a716-446655440000",
      ...>     "version" => 1
      ...>   }
      ...> })
      {:ok, %Xeno.Content.Note{}}
  """
  def import_change(attrs) when is_map(attrs) do
    with {:ok, metadata} <- extract_metadata(attrs),
         :ok <- validate_metadata(metadata),
         {:ok, text} <- parse_markdown(attrs["markdown_content"]),
         {:ok, note} <- fetch_note_with_suggestion(metadata["id"], attrs["path"]),
         :ok <- verify_version(note, metadata["version"]),
         {:ok, update_attrs} <- build_update_attrs(metadata, text) do
      Xeno.Content.Note.update(note, update_attrs)
    end
  end

  defp extract_metadata(%{"metadata" => metadata}) when is_map(metadata), do: {:ok, metadata}
  defp extract_metadata(_), do: {:error, "Missing metadata"}

  defp fetch_note_with_suggestion(note_id, path) when is_binary(note_id) do
    case Xeno.Content.Note.get(note_id) do
      {:ok, note} ->
        {:ok, note}

      {:error, _error} ->
        suggest_id_by_path(note_id, path)
    end
  end

  defp suggest_id_by_path(provided_id, path) when is_binary(path) do
    case find_note_by_path(path) do
      {:ok, found_note} ->
        {:error,
         %{
           type: :id_not_found,
           provided_id: provided_id,
           path: path,
           suggested_id: found_note.id,
           suggested_name: found_note.name,
           message:
             "Note with ID '#{provided_id}' not found. Found note '#{found_note.id}' (#{found_note.name}) at path '#{path}'."
         }}

      {:error, _} ->
        {:error,
         %{
           type: :id_not_found,
           provided_id: provided_id,
           path: path,
           suggested_id: nil,
           message: "Note with ID '#{provided_id}' not found. No existing note at path '#{path}'."
         }}
    end
  end

  defp suggest_id_by_path(_provided_id, _path) do
    {:error, %Ash.Error.Invalid{class: :invalid}}
  end

  defp verify_version(note, expected_version) when is_integer(expected_version) do
    if note.version == expected_version do
      :ok
    else
      {:error, %Ash.Error.Invalid{class: :invalid, errors: [%{message: "Version mismatch"}]}}
    end
  end

  defp build_update_attrs(metadata, text) do
    attrs = %{text: text}

    attrs =
      if metadata["name"] do
        Map.put(attrs, :name, metadata["name"])
      else
        attrs
      end

    attrs =
      if metadata["tags"] do
        Map.put(attrs, :tags, metadata["tags"])
      else
        attrs
      end

    attrs =
      if metadata["data"] do
        Map.put(attrs, :data, metadata["data"])
      else
        attrs
      end

    {:ok, attrs}
  end
end
