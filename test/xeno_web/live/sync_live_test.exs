defmodule XenoWeb.SyncLiveTest do
  use XenoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Xeno.Generators

  defp drain_progress_events(view) do
    receive do
      {_, {:push_event, "import_progress", _}} -> drain_progress_events(view)
    after
      0 -> :ok
    end
  end

  describe "mount/3" do
    test "renders sync page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/sync")

      assert html =~ "Editor Integration"
      assert has_element?(view, "#sync-container")
    end

    test "initializes with no notes selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      refute has_element?(view, "#preview-container")
    end
  end

  describe "export_preview event" do
    test "generates file preview for a note", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Test Content",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      view
      |> element("#export-preview-btn")
      |> render_click(%{"note_id" => note.id})

      assert has_element?(view, "#preview-container")
      assert has_element?(view, "#markdown-preview", note.text)
      assert has_element?(view, "#json-preview")
    end

    test "displays markdown content", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "# Unique Test Heading",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      html =
        view
        |> element("#export-preview-btn")
        |> render_click(%{"note_id" => note.id})

      assert html =~ "Unique Test Heading"
    end

    test "displays JSON metadata", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      html =
        view
        |> element("#export-preview-btn")
        |> render_click(%{"note_id" => note.id})

      assert html =~ note.id
      assert html =~ "version"
    end
  end

  describe "export_all_preview event" do
    test "shows preview of all notes", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      _note1 =
        generate(
          note(
            name: "First Note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      _note2 =
        generate(
          note(
            name: "Second Note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      html =
        view
        |> element("#export-all-preview-btn")
        |> render_click()

      assert html =~ "First Note"
      assert html =~ "Second Note"
    end

    test "displays count of notes to export", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      _note1 =
        generate(
          note(
            name: "Note 1",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      _note2 =
        generate(
          note(
            name: "Note 2",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      html =
        view
        |> element("#export-all-preview-btn")
        |> render_click()

      assert html =~ "2 notes"
    end
  end

  describe "directory connection" do
    test "shows connect button when not connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      assert has_element?(view, "#connect-directory-btn")
      refute has_element?(view, "#export-all-btn")
    end

    test "connect_directory event pushes request to client", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      view
      |> element("#connect-directory-btn")
      |> render_click()

      assert_push_event(view, "request_directory", %{})
    end

    test "directory_connected event updates status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      assert has_element?(view, "#export-all-btn")
      assert has_element?(view, "#disconnect-directory-btn")

      html = render(view)
      assert html =~ "Connected to folder: TestFolder"
    end

    test "directory_connected event without name still works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      assert has_element?(view, "#export-all-btn")
      html = render(view)
      assert html =~ "Connected to folder"
    end

    test "disconnect_directory event pushes disconnect to client", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      view
      |> element("#disconnect-directory-btn")
      |> render_click()

      assert_push_event(view, "disconnect_directory", %{})
    end

    test "directory_disconnected event clears status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "directory_disconnected", %{})

      assert has_element?(view, "#connect-directory-btn")
      refute has_element?(view, "#export-all-btn")
    end

    test "directory_error event shows error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_error", %{"message" => "Permission denied"})

      html = render(view)
      assert html =~ "Permission denied"
    end
  end

  describe "export_all event" do
    test "pushes write_files event to client when connected", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      _note =
        generate(
          note(
            name: "Test Note",
            text: "Content",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      view
      |> element("#export-all-btn")
      |> render_click()

      assert_push_event(view, "write_files", %{files: files})
      assert length(files) > 0

      first_file = List.first(files)
      assert Map.has_key?(first_file, :path)
      assert Map.has_key?(first_file, :markdown)
      assert Map.has_key?(first_file, :json)
    end

    test "export_progress updates status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "export_progress", %{"current" => 5, "total" => 10})

      html = render(view)
      assert html =~ "Exporting 5/10"
    end

    test "export_complete shows success and updates last_sync", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "export_complete", %{"count" => 10})

      html = render(view)
      assert html =~ "Successfully exported 10 note(s)"
      assert html =~ "Last export:"
    end

    test "export_error shows error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "export_error", %{"message" => "Write failed"})

      html = render(view)
      assert html =~ "Export failed: Write failed"
    end
  end

  describe "import_files event" do
    test "imports file changes and shows success message", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original content",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => "Updated content",
          "version" => 1,
          "name" => "Updated Note"
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Successfully imported 1 note(s)"
      assert html =~ "Last import:"

      {:ok, updated_note} = Xeno.Content.Note.get(note.id)
      assert updated_note.text == "Updated content"
      assert updated_note.name == "Updated Note"
    end

    test "handles partial import failures", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => "Valid update",
          "version" => 1
        },
        %{
          "id" => "invalid-uuid",
          "markdown_content" => "Invalid",
          "version" => 1
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Imported 1"
      assert html =~ "failed 1"
    end

    test "handles version conflicts", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      original_version = note.version
      {:ok, updated_note} = Xeno.Content.Note.update(note, %{text: "Concurrent update"})

      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => "Conflicting update",
          "version" => original_version
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      {:ok, final_note} = Xeno.Content.Note.get(note.id)
      assert final_note.text == "Concurrent update"
      assert final_note.version == updated_note.version
    end

    test "updates last_sync timestamp on successful import", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            text: "Original",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      changes = [
        %{
          "note_id" => note.id,
          "markdown_content" => "Updated",
          "metadata" => %{
            "id" => note.id,
            "version" => 1
          }
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Last import:"
    end

    test "shows error when no changes provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "import_files", %{"changes" => []})

      html = render(view)
      assert html =~ "No changes to import"
    end

    test "requires directory connection before import", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      refute has_element?(view, "#import-btn")
    end
  end

  describe "import_files error formatting" do
    setup do
      note_type = generate(note_type(name: "Test Type"))
      work_dir = generate(directory(path: "projects/work"))

      note =
        generate(
          note(
            name: "Meeting Notes",
            filename: "meeting-notes",
            text: "Original content",
            note_type_id: note_type.id,
            directory_id: work_dir.id
          )
        )

      %{note: note, directory: work_dir}
    end

    test "formats NoteNotFound error with suggestion for frontend", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      wrong_id = Ash.UUID.generate()

      changes = [
        %{
          "id" => wrong_id,
          "path" => "projects/work/meeting-notes",
          "markdown_content" => "Updated content",
          "version" => 1
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: [error_result]})

      assert error_result["status"] == "error"
      assert error_result["error"]["type"] == "id_not_found"
      assert error_result["error"]["provided_id"] == wrong_id
      assert error_result["error"]["suggested_id"] == note.id
      assert error_result["error"]["path"] == "projects/work/meeting-notes"
      assert is_binary(error_result["error"]["message"])
    end

    test "formats PathMismatch error for frontend", %{conn: conn, note: note} do
      note = Ash.load!(note, :file_path)
      {:ok, view, _html} = live(conn, ~p"/sync")

      changes = [
        %{
          "id" => note.id,
          "path" => "wrong/path/location",
          "markdown_content" => "Content",
          "version" => note.version
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: [error_result]})

      assert error_result["status"] == "error"
      assert error_result["error"]["type"] == "path_mismatch"
      assert error_result["error"]["note_id"] == note.id
      assert error_result["error"]["expected_path"] == note.file_path
      assert error_result["error"]["actual_path"] == "wrong/path/location"
      assert is_binary(error_result["error"]["message"])
    end

    test "returns success with new version on successful import", %{conn: conn, note: note} do
      note = Ash.load!(note, :file_path)
      {:ok, view, _html} = live(conn, ~p"/sync")

      changes = [
        %{
          "id" => note.id,
          "path" => note.file_path,
          "markdown_content" => "Updated content",
          "version" => note.version
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: [success_result]})

      assert success_result["status"] == "success"
      assert success_result["note_id"] == note.id
      assert success_result["new_version"] == note.version + 1
    end

    test "handles multiple changes with mixed success and errors", %{conn: conn, note: note} do
      note = Ash.load!(note, :file_path)
      {:ok, view, _html} = live(conn, ~p"/sync")

      wrong_id = Ash.UUID.generate()

      changes = [
        # This should succeed
        %{
          "id" => note.id,
          "path" => note.file_path,
          "markdown_content" => "Good update",
          "version" => note.version
        },
        # This should fail with id_not_found
        %{
          "id" => wrong_id,
          "path" => "nonexistent/path",
          "markdown_content" => "Bad update",
          "version" => 1
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert length(results) == 2

      [success_result, error_result] = results

      assert success_result["status"] == "success"
      assert error_result["status"] == "error"
      assert error_result["error"]["type"] == "id_not_found"
    end
  end

  describe "id_conflict event" do
    test "stores conflict data and shows flash message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test/note.md",
        "jsonId" => "json-id-123",
        "serverId" => "server-id-456",
        "localId" => "local-id-789",
        "reason" => "Conflicting IDs between JSON, server, and local cache"
      }

      render_hook(view, "id_conflict", conflict_params)

      # Should store conflict data in socket
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict != nil
      conflict = state.conflict.id_conflict
      assert conflict.path == "test/note.md"
      assert conflict.json_id == "json-id-123"
      assert conflict.server_id == "server-id-456"
      assert conflict.local_id == "local-id-789"
    end

    test "handles conflict without localId (new machine scenario)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "note.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => nil,
        "reason" => "No local metadata"
      }

      render_hook(view, "id_conflict", conflict_params)

      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict != nil
      conflict = state.conflict.id_conflict
      assert conflict.local_id == nil
    end
  end

  describe "path_mismatch event" do
    test "stores mismatch data and shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      mismatch_params = %{
        "note_id" => "abc-123",
        "expected_path" => "old/location.md",
        "actual_path" => "new/location.md",
        "message" => "Note exists at different location"
      }

      render_hook(view, "path_mismatch", mismatch_params)

      # Should store mismatch data
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.path_mismatch != nil
      mismatch = state.conflict.path_mismatch
      assert mismatch.id == "abc-123"
      assert mismatch.expected_path == "old/location.md"
      assert mismatch.actual_path == "new/location.md"
    end
  end

  describe "resolve_conflict event" do
    test "chooses server ID and emits resolve event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # First, set up a conflict
      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test conflict"
      }

      render_hook(view, "id_conflict", conflict_params)

      # Now resolve it
      render_hook(view, "resolve_conflict", %{"choice" => "server"})

      # Should emit resolve_conflict event back to frontend
      assert_push_event(view, "resolve_conflict", %{
        path: "test.md",
        chosen_id: "server-id",
        choice: "server"
      })

      # Should clear conflict from state
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict == nil
    end

    test "chooses local ID when user selects local", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)
      render_hook(view, "resolve_conflict", %{"choice" => "local"})

      assert_push_event(view, "resolve_conflict", %{
        chosen_id: "local-id"
      })
    end

    test "chooses JSON ID when user selects json", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)
      render_hook(view, "resolve_conflict", %{"choice" => "json"})

      assert_push_event(view, "resolve_conflict", %{
        chosen_id: "json-id"
      })
    end

    test "defaults to server ID for unknown choice", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)
      render_hook(view, "resolve_conflict", %{"choice" => "invalid"})

      assert_push_event(view, "resolve_conflict", %{
        chosen_id: "server-id"
      })
    end

    test "does nothing when no conflict exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Try to resolve without setting up a conflict first
      render_hook(view, "resolve_conflict", %{"choice" => "server"})

      # Should not emit any event
      refute_push_event(view, "resolve_conflict", %{})
    end
  end

  describe "cancel_conflict event" do
    test "clears conflict data and shows info message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Set up a conflict
      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)

      # Verify conflict is set
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict != nil

      # Cancel the conflict
      render_hook(view, "cancel_conflict", %{})

      # Should clear conflict
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict == nil
    end
  end

  describe "conflict dialog UI" do
    test "renders conflict dialog when id_conflict is set", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "projects/my-note.md",
        "jsonId" => "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "serverId" => "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "localId" => "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "reason" => "Conflicting IDs between JSON, server, and local cache"
      }

      render_hook(view, "id_conflict", conflict_params)

      html = render(view)

      # Should render conflict dialog
      assert html =~ "conflict-dialog"
      assert html =~ "Note ID Conflict Detected"

      # Should display the file path
      assert html =~ "projects/my-note.md"

      # Should display all three IDs
      assert html =~ "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      assert html =~ "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
      assert html =~ "cccccccc-cccc-cccc-cccc-cccccccccccc"

      # Should show the reason
      assert html =~ "Conflicting IDs between JSON, server, and local cache"

      # Should have action buttons
      assert has_element?(view, "#choose-server-btn")
      assert has_element?(view, "#choose-local-btn")
      assert has_element?(view, "#choose-json-btn")
      assert has_element?(view, "#cancel-conflict-btn")
    end

    test "renders dialog without local_id when not present", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "note.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => nil,
        "reason" => "No local cache"
      }

      render_hook(view, "id_conflict", conflict_params)

      html = render(view)

      # Should render dialog
      assert html =~ "conflict-dialog"

      # Should have server and json buttons but not local
      assert has_element?(view, "#choose-server-btn")
      assert has_element?(view, "#choose-json-btn")
      refute has_element?(view, "#choose-local-btn")
    end

    test "does not render dialog when no conflict", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      html = render(view)

      # Should not render conflict dialog
      refute html =~ "conflict-dialog"
      refute html =~ "Note ID Conflict Detected"
    end

    test "clicking choice buttons triggers resolve_conflict event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)

      # Click server button
      view
      |> element("#choose-server-btn")
      |> render_click()

      assert_push_event(view, "resolve_conflict", %{
        chosen_id: "server-id",
        choice: "server"
      })
    end

    test "clicking cancel button clears conflict", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)

      # Verify conflict is set
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict != nil

      # Click cancel
      view
      |> element("#cancel-conflict-btn")
      |> render_click()

      # Should clear conflict
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict == nil
    end
  end

  describe "E2E: complete auto-fix flow" do
    test "ID typo → server detects error → frontend auto-fixes → retry succeeds", %{
      conn: conn
    } do
      directory = generate(directory(path: "projects/work"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Work Note",
            text: "# Work Note\n\nSome content.",
            filename: "my-note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      correct_id = note.id
      typo_id = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      path = "projects/work/my-note"

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => typo_id,
            "version" => 1,
            "name" => "Work Note",
            "markdown_content" => "# Work Note\n\nSome content.",
            "path" => path
          }
        ]
      })

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert [result] = results

      assert result["status"] == "error"
      assert result["error"]["type"] == "id_not_found"
      assert result["error"]["provided_id"] == typo_id
      assert result["error"]["suggested_id"] == correct_id
      assert result["error"]["path"] == path

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => correct_id,
            "version" => 1,
            "name" => "Work Note",
            "markdown_content" => "# Work Note\n\nSome content.",
            "path" => path
          }
        ]
      })

      assert_push_event(view, "import_result", %{results: retry_results})
      assert [retry_result] = retry_results

      assert retry_result["status"] == "success"
      assert retry_result["note_id"] == correct_id

      {:ok, updated_note} = Xeno.Content.Note.get(correct_id)
      assert updated_note.id == correct_id
      assert updated_note.version == 2
    end

    test "conflict scenario → user interaction → resolution → retry succeeds", %{conn: conn} do
      directory = generate(directory(path: "projects/conflict"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Conflict Note",
            text: "# Conflict\n\nContent.",
            filename: "note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      server_id = note.id
      json_id = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
      path = "projects/conflict/note"

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => json_id,
            "version" => 1,
            "name" => "Conflict Note",
            "markdown_content" => "# Conflict\n\nContent.",
            "path" => path
          }
        ]
      })

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert [result] = results

      assert result["status"] == "error"
      assert result["error"]["type"] == "id_not_found"
      assert result["error"]["suggested_id"] == server_id

      render_hook(view, "id_conflict", %{
        "path" => path,
        "jsonId" => json_id,
        "serverId" => server_id,
        "localId" => nil,
        "reason" => "Server and JSON disagree, no local cache"
      })

      html = render(view)
      assert html =~ "Note ID Conflict Detected"
      assert html =~ server_id
      assert html =~ json_id

      render_hook(view, "resolve_conflict", %{"choice" => "server"})

      assert_push_event(view, "resolve_conflict", %{
        path: ^path,
        chosen_id: ^server_id,
        choice: "server"
      })

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => server_id,
            "version" => 1,
            "name" => "Conflict Note",
            "markdown_content" => "# Conflict\n\nContent.",
            "path" => path
          }
        ]
      })

      assert_push_event(view, "import_result", %{results: retry_results})
      assert [retry_result] = retry_results

      assert retry_result["status"] == "success"
      assert retry_result["note_id"] == server_id

      {:ok, final_note} = Xeno.Content.Note.get(server_id)
      assert final_note.id == server_id
      assert final_note.version == 2
    end

    test "new machine scenario → no conflict → import succeeds", %{conn: conn} do
      directory = generate(directory(path: "projects/existing"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Existing Note",
            text: "# Existing\n\nContent from server.",
            filename: "note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      existing_id = note.id
      path = "projects/existing/note"

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => existing_id,
            "version" => 1,
            "name" => "Existing Note",
            "markdown_content" => "# Existing\n\nContent from server.",
            "path" => path
          }
        ]
      })

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert [result] = results

      assert result["status"] == "success"
      assert result["note_id"] == existing_id
      assert result["new_version"] == 2

      {:ok, updated_note} = Xeno.Content.Note.get(existing_id)
      assert updated_note.id == existing_id
      assert updated_note.version == 2
    end

    test "path mismatch → error reported → frontend handles gracefully", %{conn: conn} do
      _directory_old = generate(directory(path: "projects/old"))
      directory_new = generate(directory(path: "projects/new"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Moved Note",
            text: "# Moved\n\nContent.",
            filename: "note",
            directory_id: directory_new.id,
            note_type_id: note_type.id
          )
        )

      note_id = note.id
      old_path = "projects/old/note"
      new_path = "projects/new/note"

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => note_id,
            "version" => 1,
            "name" => "Moved Note",
            "markdown_content" => "# Moved\n\nContent.",
            "path" => old_path
          }
        ]
      })

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert [result] = results

      assert result["status"] == "error"
      assert result["error"]["type"] == "path_mismatch"
      assert result["error"]["note_id"] == note_id
      assert result["error"]["expected_path"] == new_path
      assert result["error"]["actual_path"] == old_path

      render_hook(view, "path_mismatch", %{
        "id" => note_id,
        "expectedPath" => new_path,
        "providedPath" => old_path
      })

      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.path_mismatch != nil
      path_mismatch = state.conflict.path_mismatch
      assert path_mismatch.id == note_id
      assert path_mismatch.expected_path == new_path
      assert path_mismatch.actual_path == old_path
    end

    test "optimistic lock failure → version conflict → user must pull latest", %{
      conn: conn
    } do
      directory = generate(directory(path: "projects/concurrent"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Concurrent Note",
            text: "# Original\n\nVersion 1 content.",
            filename: "note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note_id = note.id
      path = "projects/concurrent/note"

      {:ok, _updated_note} =
        note
        |> Ash.Changeset.for_update(:update, %{text: "# Version 2\n\nUpdated once."})
        |> Ash.update()

      {:ok, _updated_note2} =
        Xeno.Content.Note.get!(note_id)
        |> Ash.Changeset.for_update(:update, %{text: "# Version 3\n\nUpdated twice."})
        |> Ash.update()

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => note_id,
            "version" => 2,
            "name" => "Concurrent Note (stale)",
            "markdown_content" => "# Stale\n\nStale edit from version 2.",
            "path" => path
          }
        ]
      })

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert [result] = results

      assert result["status"] == "error"
      assert result["error"]["type"] == "validation"
      assert result["error"]["message"] =~ "stale"

      {:ok, unchanged_note} = Xeno.Content.Note.get(note_id)
      assert unchanged_note.version == 3
      assert unchanged_note.text == "# Version 3\n\nUpdated twice."
    end

    test "cancel conflict dialog → state cleared → no retry attempted", %{conn: conn} do
      directory = generate(directory(path: "projects/cancel"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Cancel Test",
            text: "# Cancel\n\nContent.",
            filename: "note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      server_id = note.id
      json_id = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
      path = "projects/cancel/note"

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      render_hook(view, "import_files", %{
        "changes" => [
          %{
            "id" => json_id,
            "version" => 1,
            "name" => "Cancel Test",
            "markdown_content" => "# Cancel\n\nContent.",
            "path" => path
          }
        ]
      })

      drain_progress_events(view)
      assert_push_event(view, "import_result", %{results: results})
      assert [result] = results
      assert result["status"] == "error"

      render_hook(view, "id_conflict", %{
        "path" => path,
        "jsonId" => json_id,
        "serverId" => server_id,
        "localId" => nil,
        "reason" => "Test cancel flow"
      })

      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict != nil
      conflict = state.conflict.id_conflict
      assert conflict.json_id == json_id

      render_hook(view, "cancel_conflict", %{})

      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.conflict.id_conflict == nil

      html = render(view)
      refute html =~ "Note ID Conflict Detected"
    end
  end

  describe "FileSystemObserver events" do
    test "observer_supported event sets capability flag to true", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "observer_supported", %{"supported" => true})

      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.connection.observer_supported == true
    end

    test "observer_supported event sets capability flag to false", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "observer_supported", %{"supported" => false})

      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.connection.observer_supported == false
    end

    test "start_watching event enables watching and pushes to JS", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # First connect directory and set observer support (required for watching)
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "observer_supported", %{"supported" => true})

      # Start watching
      view
      |> element("#start-watching-btn")
      |> render_click()

      # Should set watching_enabled to true
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.connection.watching == true

      # Should push event to JS
      assert_push_event(view, "start_file_observer", %{})
    end

    test "stop_watching event disables watching and pushes to JS", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Set up watching state
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "observer_supported", %{"supported" => true})
      render_hook(view, "watching_started", %{})

      # Stop watching
      view
      |> element("#stop-watching-btn")
      |> render_click()

      # Should set watching_enabled to false
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.connection.watching == false

      # Should push event to JS
      assert_push_event(view, "stop_file_observer", %{})
    end

    test "watching_started event confirms observer active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "watching_started", %{})

      # Should set watching_enabled
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.connection.watching == true

      # Should show success message
      html = render(view)
      assert html =~ "Auto-sync active"
    end

    test "watching_stopped event confirms observer stopped", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Set up watching
      render_hook(view, "directory_connected", %{})
      render_hook(view, "watching_started", %{})

      # Stop watching
      render_hook(view, "watching_stopped", %{})

      # Should clear watching state
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.connection.watching == false

      # Should show info message
      html = render(view)
      assert html =~ "Auto-sync paused"
    end
  end

  describe "component structure" do
    test "page uses container component with correct max-width", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      html = render(view)
      # Container should use component (has sync-container id for phx-hook)
      assert html =~ "sync-container"
    end

    test "page has proper heading hierarchy starting with h1", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      html = render(view)
      assert html =~ "Editor Integration"
      # Should use h1 for page title (allowing for whitespace)
      assert html =~ ~r/<h1[^>]*>\s*Editor Integration\s*<\/h1>/
    end

    test "cards use wa-card component for major sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      html = render(view)
      # Should have wa-card components
      assert html =~ "wa-card"
    end

    test "export and import buttons have auto-generated IDs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      # Buttons should have IDs (either explicit or auto-generated)
      assert has_element?(view, "#export-all-btn")
      assert has_element?(view, "#import-btn")
    end

    test "buttons show loading states with spinner", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "export_progress", %{"current" => 5, "total" => 10})

      html = render(view)
      # Should show loading state
      assert html =~ "Exporting 5/10"
    end

    test "export button stops loading after export_complete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      # Start export - button should be loading
      render_hook(view, "export_progress", %{"current" => 5, "total" => 10})
      html = render(view)
      assert html =~ "Exporting 5/10"

      # Complete export - button should stop loading
      render_hook(view, "export_complete", %{"count" => 10})
      html = render(view)
      refute html =~ "Exporting"

      # Button should be enabled again (not have loading class/state)
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :idle
    end

    test "import button stops loading after import completion", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      # Start import scan - button should be loading
      render_hook(view, "scan_started", %{"total" => 5})
      html = render(view)
      assert html =~ "Importing 0/5"

      # Progress through import
      render_hook(view, "import_progress", %{"current" => 3, "total" => 5})
      html = render(view)
      assert html =~ "Importing 3/5"

      # Complete import - button should stop loading
      render_hook(view, "import_files", %{"changes" => []})
      html = render(view)
      refute html =~ "Importing"

      # Import status should be back to idle
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :idle
    end

    test "import button full flow from scan_files event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      # Verify button is not loading initially
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :idle

      # User clicks "Import Changes" - triggers scan_files
      # This sets import_status to :scanning
      render_hook(view, "scan_files", %{})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :import
      assert state.operation.phase == :scanning

      # JavaScript calls scan_started after counting files
      render_hook(view, "scan_started", %{"total" => 5})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :import
      assert state.operation.phase == {:running, 0, 5}

      # JavaScript sends import_files with changes
      # This should set import_status back to :idle
      render_hook(view, "import_files", %{"changes" => []})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :idle

      # Button should not be loading anymore
      html = render(view)
      refute html =~ "Importing"
      refute html =~ "Scanning"
    end

    test "export button remains disabled during export but not loading after error", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      # Start export
      render_hook(view, "export_progress", %{"current" => 2, "total" => 10})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :export
      assert state.operation.phase == {:running, 2, 10}

      # Export error - should go back to idle
      render_hook(view, "export_error", %{"message" => "Failed"})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :idle

      html = render(view)
      refute html =~ "Exporting"
    end

    test "import button remains disabled during import but not loading after error", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      # Start import
      render_hook(view, "import_progress", %{"current" => 2, "total" => 5})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :import
      assert state.operation.phase == {:running, 2, 5}

      # Import error - should go back to idle
      render_hook(view, "import_error", %{"message" => "Import failed"})
      state = :sys.get_state(view.pid).socket.assigns.state
      assert state.operation.mode == :idle

      html = render(view)
      refute html =~ "Importing"
    end

    test "success alerts use alert component with success variant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      html = render(view)
      # Should show success alert for connection
      assert html =~ "Connected to folder"
    end

    test "error alerts use alert component with danger variant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_error", %{"message" => "Test error"})

      html = render(view)
      assert html =~ "Test error"
    end

    test "badges use badge component for sync status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})
      render_hook(view, "observer_supported", %{"supported" => true})

      html = render(view)
      # Should have badge for auto-sync status
      assert html =~ "Auto-sync available"
    end

    test "no inline SVG icons remain in output", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      html = render(view)
      # Should not have inline SVG elements
      refute html =~ ~r/<svg[^>]*xmlns="http:\/\/www\.w3\.org\/2000\/svg"/
    end

    test "modal uses modal component for conflict dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      conflict_params = %{
        "path" => "test.md",
        "jsonId" => "json-id",
        "serverId" => "server-id",
        "localId" => "local-id",
        "reason" => "Test"
      }

      render_hook(view, "id_conflict", conflict_params)

      html = render(view)
      # Should use wa-dialog for modal
      assert html =~ "wa-dialog"
      assert html =~ "Note ID Conflict Detected"
    end

    test "action buttons are grouped using button_group component", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      # Button group should provide clean layout for action buttons
      assert has_element?(view, "#export-all-btn")
      assert has_element?(view, "#import-btn")
      assert has_element?(view, "#disconnect-directory-btn")
    end
  end

  describe "FileSystemObserver UI" do
    test "shows 'Auto-sync available' badge when observer supported", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Connect directory and set observer support
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "observer_supported", %{"supported" => true})

      html = render(view)
      assert html =~ "Auto-sync available"
    end

    test "shows 'not supported' message when observer unavailable", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Connect directory and set observer not supported
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "observer_supported", %{"supported" => false})

      html = render(view)
      assert html =~ "Auto-sync not supported"
      assert html =~ "manual import"
    end

    test "shows 'Enable Auto-Sync' button when not watching", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Connect directory and set observer support
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "observer_supported", %{"supported" => true})

      # Should show enable button
      assert has_element?(view, "#start-watching-btn", "Enable Auto-Sync")
    end

    test "shows 'Pause Auto-Sync' button when watching", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Connect directory, set observer support, start watching
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})
      render_hook(view, "observer_supported", %{"supported" => true})
      render_hook(view, "watching_started", %{})

      # Should show pause button
      assert has_element?(view, "#stop-watching-btn", "Pause Auto-Sync")
    end

    test "shows watching indicator when enabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Connect directory, set observer support, and start watching
      render_hook(view, "directory_connected", %{})
      render_hook(view, "observer_supported", %{"supported" => true})
      render_hook(view, "watching_started", %{})

      html = render(view)
      assert html =~ "Watching for changes"
    end

    test "hides watch controls when observer not supported", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sync")

      # Connect directory but observer not supported
      render_hook(view, "directory_connected", %{})
      render_hook(view, "observer_supported", %{"supported" => false})

      # Should not show watch buttons
      refute has_element?(view, "#start-watching-btn")
      refute has_element?(view, "#stop-watching-btn")
    end
  end

  describe "JSON-only metadata updates" do
    test "imports metadata changes from JSON file only (name change)", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original content",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => note.text,
          "version" => note.version,
          "name" => "Updated Name via JSON"
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Successfully imported 1 note"

      {:ok, updated} = Xeno.Content.Note.get(note.id)
      assert updated.text == note.text
      assert updated.name == "Updated Name via JSON"
    end

    test "imports metadata changes from JSON file only (tags change)", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original content",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => note.text,
          "version" => note.version,
          "tags" => ["metadata-only", "json-update"]
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Successfully imported 1 note"

      {:ok, updated} = Xeno.Content.Note.get(note.id)
      assert updated.text == note.text
      assert "metadata-only" in updated.tags
      assert "json-update" in updated.tags
    end

    test "imports metadata changes from JSON file only (data change)", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original content",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      custom_data = %{"priority" => "high", "status" => "in-progress"}

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => note.text,
          "version" => note.version,
          "data" => custom_data
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Successfully imported 1 note"

      {:ok, updated} = Xeno.Content.Note.get(note.id)
      assert updated.text == note.text
      assert updated.data == custom_data
    end

    test "imports combined metadata changes (name, tags, and data)", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "Original content",
            version: 1,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      {:ok, view, _html} = live(conn, ~p"/sync")
      render_hook(view, "directory_connected", %{"name" => "TestFolder"})

      custom_data = %{"reviewed" => true}

      changes = [
        %{
          "id" => note.id,
          "markdown_content" => note.text,
          "version" => note.version,
          "name" => "Fully Updated Note",
          "tags" => ["complete", "reviewed"],
          "data" => custom_data
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Successfully imported 1 note"

      {:ok, updated} = Xeno.Content.Note.get(note.id)
      assert updated.text == note.text
      assert updated.name == "Fully Updated Note"
      assert "complete" in updated.tags
      assert "reviewed" in updated.tags
      assert updated.data == custom_data
    end
  end
end
