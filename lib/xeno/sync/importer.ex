defmodule Xeno.Sync.Importer do
  @moduledoc """
  Imports file changes from the local file system into the database.

  Uses the Note.import_from_filesystem action to handle validation,
  parsing, and updating. Provides helpful error messages when IDs don't match.
  """

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

  Now uses the Note.import_from_filesystem action which handles:
  - Parsing markdown content
  - Validating UUID format and version presence (via Ash)
  - Optimistic locking via Ash's built-in version checking

  Accepts a map with the following keys:
  - `id`: UUID of the note to update
  - `path`: File system path (optional, used for ID suggestion)
  - `markdown_content`: Updated text content from the .md file
  - `version`: Version number for optimistic locking
  - `name`: Optional updated name
  - `tags`: Optional updated tags
  - `data`: Optional updated data

  Returns:
  - `{:ok, updated_note}` on success
  - `{:error, reason}` on validation failure or version conflict
  - `{:error, %{type: :id_not_found, ...}}` when ID is wrong but path-based suggestion available

  ## Examples

      iex> import_change(%{
      ...>   "id" => "550e8400-e29b-41d4-a716-446655440000",
      ...>   "markdown_content" => "# Updated content",
      ...>   "version" => 1
      ...> })
      {:ok, %Xeno.Content.Note{}}
  """
  def import_change(attrs) when is_map(attrs) do
    note_id = attrs["id"]
    path = attrs["path"]
    expected_version = attrs["version"]

    case Xeno.Content.Note.get(note_id) do
      {:ok, note} ->
        case verify_version(note, expected_version) do
          :ok ->
            update_attrs = Map.drop(attrs, ["id", "version"])
            Xeno.Content.Note.import_from_filesystem(note, update_attrs)

          {:error, _} = error ->
            error
        end

      {:error, _error} ->
        suggest_id_by_path(note_id, path)
    end
  end

  defp verify_version(_note, nil), do: :ok

  defp verify_version(note, expected_version) when is_integer(expected_version) do
    if note.version == expected_version do
      :ok
    else
      {:error,
       %Ash.Error.Invalid{
         class: :invalid,
         errors: [
           %{
             field: :version,
             message: "Version mismatch: expected #{expected_version}, got #{note.version}"
           }
         ]
       }}
    end
  end

  defp verify_version(_note, _expected_version), do: :ok

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

  defp suggest_id_by_path(provided_id, _path) do
    {:error,
     %{
       type: :id_not_found,
       provided_id: provided_id,
       path: nil,
       suggested_id: nil,
       message: "Note with ID '#{provided_id}' not found."
     }}
  end
end
