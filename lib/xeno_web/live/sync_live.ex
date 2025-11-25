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
       error: nil,
       sync_errors: nil,
       id_conflict: nil,
       path_mismatch: nil
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
            name: note.name,
            version: note.version
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
     |> assign(sync_status: :idle, sync_error: nil, last_sync: DateTime.utc_now())
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
    socket =
      socket
      |> assign(sync_error: nil)
      |> push_event("scan_files", %{})

    {:noreply, socket}
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
    results =
      Enum.map(changes, fn change ->
        case Sync.import_change(change) do
          {:ok, note} ->
            %{
              "status" => "success",
              "note_id" => note.id,
              "new_version" => note.version
            }

          {:error, %Ash.Error.Invalid{errors: errors}} ->
            format_import_error(errors)

          {:error, error} ->
            %{
              "status" => "error",
              "error" => %{
                "type" => "unknown",
                "message" => Exception.message(error)
              }
            }
        end
      end)

    success_count = Enum.count(results, &(&1["status"] == "success"))
    error_count = Enum.count(results, &(&1["status"] == "error"))

    socket =
      socket
      |> assign(last_sync: DateTime.utc_now())
      |> push_event("import_result", %{"results" => results})

    socket =
      if error_count == 0 do
        put_flash(socket, :info, "Successfully imported #{success_count} note(s)")
      else
        put_flash(socket, :info, "Imported #{success_count}, failed #{error_count}")
      end

    {:noreply, socket}
  end

  defp format_import_error([%Xeno.Content.Errors.NoteNotFound{} = error | _]) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "id_not_found",
        "provided_id" => error.provided_id,
        "suggested_id" => error.suggested_id,
        "path" => error.file_path,
        "message" => Exception.message(error)
      }
    }
  end

  defp format_import_error([%Xeno.Content.Errors.PathMismatch{} = error | _]) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "path_mismatch",
        "note_id" => error.note_id,
        "expected_path" => error.expected_path,
        "actual_path" => error.actual_path,
        "message" => Exception.message(error)
      }
    }
  end

  defp format_import_error([error | _]) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "unknown",
        "message" => Exception.message(error)
      }
    }
  end

  defp format_import_error([]) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "unknown",
        "message" => "Unknown error occurred"
      }
    }
  end

  @impl true
  def handle_event("id_conflict", params, socket) do
    %{
      "path" => path,
      "jsonId" => json_id,
      "serverId" => server_id,
      "localId" => local_id,
      "reason" => reason
    } = params

    conflict_data = %{
      path: path,
      json_id: json_id,
      server_id: server_id,
      local_id: local_id,
      reason: reason
    }

    {:noreply,
     socket
     |> assign(id_conflict: conflict_data)
     |> put_flash(
       :warning,
       "ID conflict detected for #{path}. Please resolve the conflict."
     )}
  end

  @impl true
  def handle_event("path_mismatch", params, socket) do
    %{
      "note_id" => note_id,
      "expected_path" => expected_path,
      "actual_path" => actual_path,
      "message" => message
    } = params

    mismatch_data = %{
      note_id: note_id,
      expected_path: expected_path,
      actual_path: actual_path,
      message: message
    }

    {:noreply,
     socket
     |> assign(path_mismatch: mismatch_data)
     |> put_flash(
       :error,
       "Path mismatch: Note #{note_id} exists at #{actual_path}, but file is at #{expected_path}"
     )}
  end

  @impl true
  def handle_event("resolve_conflict", %{"choice" => choice}, socket) do
    case socket.assigns.id_conflict do
      nil ->
        {:noreply, socket}

      conflict ->
        # Determine which ID to use based on choice
        chosen_id =
          case choice do
            "server" -> conflict.server_id
            "local" -> conflict.local_id
            "json" -> conflict.json_id
            _ -> conflict.server_id
          end

        # Emit event back to FileSystemHook to apply the chosen ID
        socket =
          socket
          |> push_event("resolve_conflict", %{
            path: conflict.path,
            chosen_id: chosen_id,
            choice: choice
          })
          |> assign(id_conflict: nil)
          |> put_flash(:info, "Conflict resolved. Retrying import with chosen ID...")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_conflict", _params, socket) do
    {:noreply,
     socket
     |> assign(id_conflict: nil)
     |> put_flash(:info, "Conflict resolution cancelled")}
  end

  # Component to display error messages
  def error(%{error: %Ash.Error.Invalid{errors: [%{message: message} | []]}} = assigns) do
    assigns = Map.put(assigns, :message, message)

    ~H"""
    <.error_message>{@message}</.error_message>
    """
  end

  def error(%{error: %Ash.Error.Invalid{errors: errors}} = assigns) do
    assigns = Map.put(assigns, :errors, errors)

    ~H"""
    <ul>
      <li :for={%{message: msg} <- @errors}>
        <.error_message>{msg}</.error_message>
      </li>
    </ul>
    """
  end

  def error(assigns) do
    ~H"<span></span>"
  end

  slot :inner_block, required: true

  def error_message(assigns) do
    ~H"""
    <div>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
