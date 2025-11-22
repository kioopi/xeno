defmodule Xeno.Sync do
  @moduledoc """
  Public API for sync operations.

  Coordinates between export and import operations,
  handles batching, error recovery, and status reporting.
  """

  alias Xeno.Sync.{Exporter, Importer, TreeBuilder}
  alias Xeno.Content.Note

  @doc """
  Exports all notes for initial sync.

  Returns a list of {note, path} tuples where each tuple contains
  the note struct and its relative file path.

  ## Examples

      iex> export_all()
      [
        {%Note{name: "Architecture"}, "projects/web_app/architecture"},
        {%Note{name: "TODO"}, "projects/web_app/todo"}
      ]
  """
  def export_all do
    TreeBuilder.build_sync_tree()
  end

  @doc """
  Exports a single note for re-sync.

  Returns a tuple containing the markdown content and JSON metadata string.

  ## Examples

      iex> export_note(note_id)
      {:ok, {"# Note content", "{\\"id\\": \\"...\\"}"}}

      iex> export_note("non-existent-id")
      {:error, %Ash.Error.Query.NotFound{}}
  """
  def export_note(note_id) do
    case Note.get(note_id) do
      {:ok, note} ->
        Exporter.export_note(note)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Imports a single file change from the filesystem.

  Delegates to `Xeno.Sync.Importer.import_change/1`.

  ## Examples

      iex> import_change(%{
      ...>   "note_id" => "550e8400-e29b-41d4-a716-446655440000",
      ...>   "markdown_content" => "Updated content",
      ...>   "metadata" => %{"id" => "...", "version" => 1}
      ...> })
      {:ok, %Note{}}
  """
  def import_change(attrs) do
    Importer.import_change(attrs)
  end

  @doc """
  Imports a batch of file changes from the filesystem.

  Processes each change independently and collects results.
  Continues processing even if individual imports fail.

  Returns a summary with:
  - `:imported` - Number of successful imports
  - `:failed` - Number of failed imports
  - `:errors` - List of error reasons for failed imports

  ## Examples

      iex> import_changes([
      ...>   %{"note_id" => "...", "markdown_content" => "...", "metadata" => %{...}},
      ...>   %{"note_id" => "...", "markdown_content" => "...", "metadata" => %{...}}
      ...> ])
      {:ok, %{imported: 2, failed: 0, errors: []}}
  """
  def import_changes(changes) when is_list(changes) do
    results =
      Enum.map(changes, fn change ->
        import_change(change)
      end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    # TODO: errors should be a map "path/to/filename" -> [errors]
    # so the output can be more helpful

    {:ok,
     %{
       imported: length(successes),
       failed: length(failures),
       errors: Enum.map(failures, fn {:error, err} -> err end)
     }}
  end
end
