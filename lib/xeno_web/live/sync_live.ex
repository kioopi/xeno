defmodule XenoWeb.SyncLive do
  use XenoWeb, :live_view

  alias Xeno.Sync
  alias XenoWeb.Sync.State

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Editor Integration",
       state: State.new(),
       error: nil
     )}
  end

  @impl true
  def handle_event("export_preview", %{"note_id" => note_id}, socket) do
    case Sync.export_note(note_id) do
      {:ok, {markdown, json_string}} ->
        state =
          State.set_single_preview(socket.assigns.state, note_id, %{
            markdown: markdown,
            json: json_string
          })

        {:noreply,
         socket
         |> assign(state: state)}

      {:error, _error} ->
        state = State.clear_preview(socket.assigns.state)

        {:noreply,
         socket
         |> assign(state: state)
         |> put_flash(:error, "Failed to export note")}
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

    state =
      State.set_all_preview(socket.assigns.state, %{
        items: preview_items,
        count: length(preview_items)
      })

    {:noreply,
     socket
     |> assign(state: state)}
  end

  @impl true
  def handle_event("connect_directory", _params, socket) do
    {:noreply, push_event(socket, "request_directory", %{})}
  end

  @impl true
  def handle_event("directory_connected", %{"name" => name}, socket) do
    state = State.connect(socket.assigns.state, name)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Connected to folder: #{name}")}
  end

  def handle_event("directory_connected", _params, socket) do
    state = State.connect(socket.assigns.state, nil)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Folder connected successfully")}
  end

  @impl true
  def handle_event("directory_disconnected", _params, socket) do
    state = State.disconnect(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Folder disconnected")}
  end

  @impl true
  def handle_event("directory_error", %{"message" => message}, socket) do
    state = State.set_error(socket.assigns.state, message)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:error, message)}
  end

  @impl true
  def handle_event("disconnect_directory", _params, socket) do
    {:noreply, push_event(socket, "disconnect_directory", %{})}
  end

  @impl true
  def handle_event("export_all", _params, socket) do
    start_time = System.monotonic_time(:millisecond)

    case State.start_export(socket.assigns.state, start_time) do
      {:error, :operation_in_progress, _state} ->
        {:noreply, put_flash(socket, :error, "Operation already in progress")}

      state ->
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
         |> assign(state: state)
         |> push_event("write_files", %{files: files})}
    end
  end

  @impl true
  def handle_event("export_progress", %{"current" => current, "total" => total}, socket) do
    # Start export if not already started (for direct test calls)
    state =
      if socket.assigns.state.operation.mode != :export do
        State.start_export(socket.assigns.state, System.monotonic_time(:millisecond))
      else
        socket.assigns.state
      end

    state = State.export_progress(state, current, total)

    {:noreply,
     socket
     |> assign(state: state)}
  end

  @impl true
  def handle_event("export_complete", %{"count" => count}, socket) do
    # Start export if not already started (for direct test calls)
    state =
      if socket.assigns.state.operation.mode != :export do
        State.start_export(socket.assigns.state, System.monotonic_time(:millisecond))
      else
        socket.assigns.state
      end

    state = State.finish_export(state, count)
    duration_text = State.format_duration(state.operation.last.duration_ms)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Successfully exported #{count} note(s) in #{duration_text}")}
  end

  @impl true
  def handle_event("export_error", %{"message" => message}, socket) do
    state = State.fail_export(socket.assigns.state, message)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:error, "Export failed: #{message}")}
  end

  @impl true
  def handle_event("scan_files", _params, socket) do
    start_time = System.monotonic_time(:millisecond)

    case State.start_import(socket.assigns.state, start_time) do
      {:error, :operation_in_progress, _state} ->
        {:noreply, put_flash(socket, :error, "Operation already in progress")}

      state ->
        {:noreply,
         socket
         |> assign(state: state)
         |> push_event("scan_files", %{})}
    end
  end

  @impl true
  def handle_event("scan_started", %{"total" => total}, socket) do
    # Start import if not already started (for direct test calls)
    state =
      if socket.assigns.state.operation.mode != :import do
        State.start_import(socket.assigns.state, System.monotonic_time(:millisecond))
      else
        socket.assigns.state
      end

    state = State.import_scan_started(state, total)

    {:noreply,
     socket
     |> assign(state: state)}
  end

  @impl true
  def handle_event("import_progress", %{"current" => current, "total" => total}, socket) do
    # Start import if not already started (for direct test calls)
    state =
      if socket.assigns.state.operation.mode != :import do
        socket.assigns.state
        |> State.start_import(System.monotonic_time(:millisecond))
        |> State.import_scan_started(total)
      else
        socket.assigns.state
      end

    state = State.import_progress(state, current, total)

    {:noreply,
     socket
     |> assign(state: state)}
  end

  @impl true
  def handle_event("import_error", %{"message" => message}, socket) do
    state = State.fail_import(socket.assigns.state, message)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:error, "Import error: #{message}")}
  end

  @impl true
  def handle_event("import_files", %{"changes" => []}, socket) do
    # For empty changes, just complete the import with empty results
    state = State.complete_import(socket.assigns.state, [])

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "No changes to import")}
  end

  @impl true
  def handle_event("import_files", %{"changes" => changes}, socket) when is_list(changes) do
    # Start import if not already in import mode (for direct calls from tests/hooks)
    state =
      if socket.assigns.state.operation.mode != :import do
        State.start_import(socket.assigns.state, System.monotonic_time(:millisecond))
      else
        socket.assigns.state
      end

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

    state = State.complete_import(state, results)

    # Safely access duration_ms and counts
    {duration_text, success_count, error_count} =
      case state.operation.last do
        nil ->
          {"0ms", 0, 0}

        last ->
          {State.format_duration(last.duration_ms), last.count, last.failed}
      end

    socket =
      socket
      |> assign(state: state)
      |> push_event("import_result", %{results: results})

    socket =
      if error_count == 0 do
        put_flash(
          socket,
          :info,
          "Successfully imported #{success_count} note(s) in #{duration_text}"
        )
      else
        put_flash(
          socket,
          :info,
          "Imported #{success_count}, failed #{error_count} in #{duration_text}"
        )
      end

    {:noreply, socket}
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

    state = State.set_id_conflict(socket.assigns.state, conflict_data)

    {:noreply,
     socket
     |> assign(state: state)
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

    state = State.set_path_mismatch(socket.assigns.state, mismatch_data)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(
       :error,
       "Path mismatch: Note #{note_id} exists at #{actual_path}, but file is at #{expected_path}"
     )}
  end

  @impl true
  def handle_event("resolve_conflict", %{"choice" => choice}, socket) do
    case socket.assigns.state.conflict.id_conflict do
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

        state = State.clear_id_conflict(socket.assigns.state)

        # Emit event back to FileSystemHook to apply the chosen ID
        socket =
          socket
          |> assign(state: state)
          |> push_event("resolve_conflict", %{
            path: conflict.path,
            chosen_id: chosen_id,
            choice: choice
          })
          |> put_flash(:info, "Conflict resolved. Retrying import with chosen ID...")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_conflict", _params, socket) do
    state = State.clear_id_conflict(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Conflict resolution cancelled")}
  end

  @impl true
  def handle_event("clear_errors", _params, socket) do
    state = State.clear_errors(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)}
  end

  @impl true
  def handle_event("observer_supported", %{"supported" => supported}, socket) do
    state = State.set_observer_support(socket.assigns.state, supported)

    {:noreply,
     socket
     |> assign(state: state)}
  end

  @impl true
  def handle_event("start_watching", _params, socket) do
    state = State.start_watching(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)
     |> push_event("start_file_observer", %{})}
  end

  @impl true
  def handle_event("stop_watching", _params, socket) do
    state = State.stop_watching(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)
     |> push_event("stop_file_observer", %{})}
  end

  @impl true
  def handle_event("watching_started", _params, socket) do
    state = State.start_watching(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Auto-sync active")}
  end

  @impl true
  def handle_event("watching_stopped", _params, socket) do
    state = State.stop_watching(socket.assigns.state)

    {:noreply,
     socket
     |> assign(state: state)
     |> put_flash(:info, "Auto-sync paused")}
  end

  # Helper functions for formatting import errors

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
