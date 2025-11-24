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

  Uses the Note.import_from_filesystem generic action which handles:
  - ID resolution with path-based fallback and suggestions
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
  - `{:error, %NoteNotFound{}}` with suggestion data when ID not found

  ## Examples

      iex> import_change(%{
      ...>   "id" => "550e8400-e29b-41d4-a716-446655440000",
      ...>   "markdown_content" => "# Updated content",
      ...>   "version" => 1
      ...> })
      {:ok, %Xeno.Content.Note{}}
  """
  def import_change(attrs) when is_map(attrs) do
    ash_attrs = %{
      id: attrs["id"],
      path: attrs["path"],
      markdown_content: attrs["markdown_content"],
      version: attrs["version"],
      name: attrs["name"],
      tags: attrs["tags"],
      data: attrs["data"]
    }

    Xeno.Content.Note.import_from_filesystem(ash_attrs)
  end
end
