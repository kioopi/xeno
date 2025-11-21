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
       selected_note_id: nil,
       directory_connected: false,
       directory_name: nil,
       sync_status: :idle,
       last_sync: nil,
       error: nil
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

  @impl true
  def handle_event("connect_directory", _params, socket) do
    {:noreply, push_event(socket, "request_directory", %{})}
  end

  @impl true
  def handle_event("directory_connected", %{"name" => name}, socket) do
    {:noreply,
     socket
     |> assign(directory_connected: true, directory_name: name, error: nil)
     |> put_flash(:info, "Connected to folder: #{name}")}
  end

  def handle_event("directory_connected", _params, socket) do
    {:noreply,
     socket
     |> assign(directory_connected: true, error: nil)
     |> put_flash(:info, "Folder connected successfully")}
  end

  @impl true
  def handle_event("directory_disconnected", _params, socket) do
    {:noreply,
     socket
     |> assign(directory_connected: false, directory_name: nil)
     |> put_flash(:info, "Folder disconnected")}
  end

  @impl true
  def handle_event("directory_error", %{"message" => message}, socket) do
    {:noreply,
     socket
     |> assign(error: message)
     |> put_flash(:error, message)}
  end

  @impl true
  def handle_event("disconnect_directory", _params, socket) do
    {:noreply, push_event(socket, "disconnect_directory", %{})}
  end

  @impl true
  def handle_event("export_all", _params, socket) do
    notes_with_paths = Sync.export_all()

    files =
      Enum.map(notes_with_paths, fn {note, path} ->
        {:ok, {markdown, json_string}} = Sync.export_note(note.id)

        %{
          path: path,
          markdown: markdown,
          json: json_string,
          metadata: %{
            note_id: note.id,
            name: note.name
          }
        }
      end)

    {:noreply,
     socket
     |> assign(sync_status: :exporting)
     |> push_event("write_files", %{files: files})}
  end

  @impl true
  def handle_event("export_progress", %{"current" => current, "total" => total}, socket) do
    {:noreply, assign(socket, sync_status: {:exporting, current, total})}
  end

  @impl true
  def handle_event("export_complete", %{"count" => count}, socket) do
    {:noreply,
     socket
     |> assign(sync_status: :idle, last_sync: DateTime.utc_now())
     |> put_flash(:info, "Successfully exported #{count} note(s)")}
  end

  @impl true
  def handle_event("export_error", %{"message" => message}, socket) do
    {:noreply,
     socket
     |> assign(sync_status: :idle, error: message)
     |> put_flash(:error, "Export failed: #{message}")}
  end

  @impl true
  def handle_event("scan_files", _params, socket) do
    {:noreply, push_event(socket, "scan_files", %{})}
  end

  @impl true
  def handle_event("import_error", %{"message" => message}, socket) do
    {:noreply,
     socket
     |> assign(error: message)
     |> put_flash(:error, "Import error: #{message}")}
  end

  @impl true
  def handle_event("import_files", %{"changes" => []}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "No changes to import")}
  end

  @impl true
  def handle_event("import_files", %{"changes" => changes}, socket) when is_list(changes) do
    {:ok, %{imported: imported, failed: failed}} = Sync.import_changes(changes)

    socket =
      if failed == 0 do
        socket
        |> assign(last_sync: DateTime.utc_now())
        |> put_flash(:info, "Successfully imported #{imported} note(s)")
      else
        socket
        |> assign(last_sync: DateTime.utc_now())
        |> put_flash(:info, "Imported #{imported}, failed #{failed}")
      end

    {:noreply, socket}
  end
end
