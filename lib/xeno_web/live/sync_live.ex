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
       import_status: :idle,
       operation_start_time: nil,
       last_operation: nil,
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
     |> assign(sync_status: :exporting, operation_start_time: System.monotonic_time(:millisecond))
     |> push_event("write_files", %{files: files})}
  end

  @impl true
  def handle_event("export_progress", %{"current" => current, "total" => total}, socket) do
    {:noreply, assign(socket, sync_status: {:exporting, current, total})}
  end

  @impl true
  def handle_event("export_complete", %{"count" => count}, socket) do
    duration = calculate_duration(socket.assigns.operation_start_time)
    duration_text = format_duration(duration)

    last_operation = %{
      type: :export,
      count: count,
      duration: duration,
      timestamp: DateTime.utc_now()
    }

    {:noreply,
     socket
     |> assign(
       sync_status: :idle,
       sync_error: nil,
       last_sync: DateTime.utc_now(),
       last_operation: last_operation,
       operation_start_time: nil
     )
     |> put_flash(:info, "Successfully exported #{count} note(s) in #{duration_text}")}
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
      |> assign(
        sync_error: nil,
        import_status: :scanning,
        operation_start_time: System.monotonic_time(:millisecond)
      )
      |> push_event("scan_files", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("scan_started", %{"total" => total}, socket) do
    {:noreply, assign(socket, import_status: {:importing, 0, total})}
  end

  @impl true
  def handle_event("import_progress", %{"current" => current, "total" => total}, socket) do
    {:noreply, assign(socket, import_status: {:importing, current, total})}
  end

  @impl true
  def handle_event("import_error", %{"message" => message}, socket) do
    {:noreply,
     socket
     |> assign(error: message, import_status: :idle)
     |> put_flash(:error, "Import error: #{message}")}
  end

  @impl true
  def handle_event("import_files", %{"changes" => []}, socket) do
    {:noreply,
     socket
     |> assign(import_status: :idle)
     |> put_flash(:info, "No changes to import")}
  end

  @impl true
  def handle_event("import_files", %{"changes" => changes}, socket) when is_list(changes) do
    results =
      Enum.with_index(changes, fn change, _idx ->
        case Sync.import_change(change) do
          {:ok, note} ->
            %{
              "status" => "success",
              "note_id" => note.id,
              "new_version" => note.version
            }

          {:error, %Ash.Error.Invalid{errors: errors}} ->
            format_import_error(errors, change)

          {:error, error} ->
            %{
              "status" => "error",
              "error" => %{
                "type" => "unknown",
                "message" => Exception.message(error),
                "file_path" => Map.get(change, "path"),
                "note_name" => Map.get(change, "name")
              }
            }
        end
      end)

    success_count = Enum.count(results, &(&1["status"] == "success"))
    error_count = Enum.count(results, &(&1["status"] == "error"))

    # Calculate operation duration
    duration = calculate_duration(socket.assigns.operation_start_time)
    duration_text = format_duration(duration)

    # Collect detailed errors for display
    sync_errors =
      results
      |> Enum.filter(&(&1["status"] == "error"))
      |> Enum.map(& &1["error"])

    last_operation = %{
      type: :import,
      count: success_count,
      failed: error_count,
      duration: duration,
      timestamp: DateTime.utc_now()
    }

    socket =
      socket
      |> assign(
        last_sync: DateTime.utc_now(),
        import_status: :idle,
        last_operation: last_operation,
        operation_start_time: nil,
        sync_errors: if(sync_errors == [], do: nil, else: sync_errors)
      )
      |> push_event("import_result", %{results: results})

    socket =
      if error_count == 0 do
        put_flash(socket, :info, "Successfully imported #{success_count} note(s) in #{duration_text}")
      else
        put_flash(socket, :info, "Imported #{success_count}, failed #{error_count} in #{duration_text}")
      end

    {:noreply, socket}
  end

  defp format_import_error([%Xeno.Content.Errors.NoteNotFound{} = error | _], change) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "id_not_found",
        "provided_id" => error.provided_id,
        "suggested_id" => error.suggested_id,
        "path" => error.file_path,
        "file_path" => error.file_path,
        "note_name" => Map.get(change, "name"),
        "message" => Exception.message(error)
      }
    }
  end

  defp format_import_error([%Xeno.Content.Errors.PathMismatch{} = error | _], change) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "path_mismatch",
        "note_id" => error.note_id,
        "expected_path" => error.expected_path,
        "actual_path" => error.actual_path,
        "file_path" => Map.get(change, "path"),
        "note_name" => Map.get(change, "name"),
        "message" => Exception.message(error)
      }
    }
  end

  defp format_import_error([error | _], change) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "validation",
        "message" => Exception.message(error),
        "file_path" => Map.get(change, "path"),
        "note_name" => Map.get(change, "name")
      }
    }
  end

  defp format_import_error([], change) do
    %{
      "status" => "error",
      "error" => %{
        "type" => "unknown",
        "message" => "Unknown error occurred",
        "file_path" => Map.get(change, "path"),
        "note_name" => Map.get(change, "name")
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
    # Handle both snake_case (from TypeScript) and camelCase (from tests)
    note_id = params["note_id"] || params["id"]
    expected_path = params["expected_path"] || params["expectedPath"]
    actual_path = params["actual_path"] || params["providedPath"]
    message = params["message"]

    mismatch_data = %{
      id: note_id,
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

  @impl true
  def handle_event("clear_errors", _params, socket) do
    {:noreply, assign(socket, sync_errors: nil, error: nil)}
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

  # Helper functions for duration tracking

  defp calculate_duration(nil), do: 0

  defp calculate_duration(start_time) do
    System.monotonic_time(:millisecond) - start_time
  end

  defp format_duration(duration_ms) when duration_ms < 1000 do
    "#{duration_ms}ms"
  end

  defp format_duration(duration_ms) when duration_ms < 60_000 do
    seconds = Float.round(duration_ms / 1000, 1)
    "#{seconds}s"
  end

  defp format_duration(duration_ms) do
    minutes = div(duration_ms, 60_000)
    seconds = div(rem(duration_ms, 60_000), 1000)
    "#{minutes}m #{seconds}s"
  end
end
