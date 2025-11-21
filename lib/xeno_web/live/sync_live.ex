defmodule XenoWeb.SyncLive do
  use XenoWeb, :live_view

  alias Xeno.Sync

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Editor Integration",
       preview_mode: nil,
       preview_data: nil,
       selected_note_id: nil
     )}
  end

  @impl true
  def handle_event("export_preview", %{"note_id" => note_id}, socket) do
    case Sync.export_note(note_id) do
      {:ok, {markdown, json_string}} ->
        {:noreply,
         socket
         |> assign(
           preview_mode: :single,
           preview_data: %{
             markdown: markdown,
             json: json_string
           },
           selected_note_id: note_id
         )}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to export note")
         |> assign(preview_mode: nil, preview_data: nil)}
    end
  end

  @impl true
  def handle_event("export_all_preview", _params, socket) do
    notes_with_paths = Sync.export_all()

    preview_items =
      Enum.map(notes_with_paths, fn {note, path} ->
        {:ok, {markdown, json_string}} = Sync.export_note(note.id)

        %{
          note: note,
          path: path,
          markdown: markdown,
          json: json_string
        }
      end)

    {:noreply,
     socket
     |> assign(
       preview_mode: :all,
       preview_data: %{
         items: preview_items,
         count: length(preview_items)
       }
     )}
  end
end
