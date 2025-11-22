defmodule Xeno.Content.Preparations.ParseFilePath do
  @moduledoc """
  Preparation that parses a file path argument into directory path and filename components.

  Used by the by_file_path action to split the incoming path
  (e.g., "projects/work/meeting-notes.md") into:
  - directory_path: "projects/work"
  - filename: "meeting-notes.md"

  Then applies filters to find the matching note.
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    file_path = Ash.Query.get_argument(query, :file_path)

    case parse_file_path(file_path) do
      {:ok, directory_path, filename} ->
        query
        |> Ash.Query.filter(filename == ^filename)
        |> Ash.Query.after_action(fn _query, results ->
          loaded_results = Ash.load!(results, :directory)

          matching_note =
            Enum.find(loaded_results, fn note ->
              note.directory.path == directory_path
            end)

          case matching_note do
            nil -> {:ok, []}
            note -> {:ok, [note]}
          end
        end)

      {:error, :invalid_path} ->
        Ash.Query.add_error(query, "Invalid file path format. Expected 'directory/path/filename'.")
    end
  end

  defp parse_file_path(path) when is_binary(path) and path != "" do
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

  defp parse_file_path(_), do: {:error, :invalid_path}
end
