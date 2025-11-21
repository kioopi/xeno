defmodule XenoWeb.SyncLiveTest do
  use XenoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Xeno.Generators

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

      note = generate(
        note(
          name: "Test Note",
          text: "# Test Content\n\nThis is test content.",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      {:ok, view, _html} = live(conn, ~p"/sync")

      view
      |> element("#export-preview-btn")
      |> render_click(%{"note_id" => note.id})

      assert has_element?(view, "#preview-container")
      assert has_element?(view, "#markdown-preview")
      assert has_element?(view, "#json-preview")
    end

    test "displays markdown content", %{conn: conn} do
      directory = generate(directory(path: "test"))
      note_type = generate(note_type(name: "Note"))

      note = generate(
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

      note = generate(
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

      _note1 = generate(
        note(
          name: "First Note",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      _note2 = generate(
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

      _note1 = generate(
        note(
          name: "Note 1",
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

      _note2 = generate(
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

      _note = generate(
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
      assert html =~ "Last sync:"
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
          "note_id" => note.id,
          "markdown_content" => "Updated content",
          "metadata" => %{
            "id" => note.id,
            "version" => 1,
            "name" => "Updated Note"
          }
        }
      ]

      render_hook(view, "import_files", %{"changes" => changes})

      html = render(view)
      assert html =~ "Successfully imported 1 note(s)"
      assert html =~ "Last sync:"

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
          "note_id" => note.id,
          "markdown_content" => "Valid update",
          "metadata" => %{
            "id" => note.id,
            "version" => 1
          }
        },
        %{
          "note_id" => "invalid-uuid",
          "markdown_content" => "Invalid",
          "metadata" => %{
            "id" => "invalid-uuid",
            "version" => 1
          }
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

      {:ok, updated_note} = Xeno.Content.Note.update(note, %{text: "Concurrent update"})

      {:ok, view, _html} = live(conn, ~p"/sync")

      render_hook(view, "directory_connected", %{})

      changes = [
        %{
          "note_id" => note.id,
          "markdown_content" => "Conflicting update",
          "metadata" => %{
            "id" => note.id,
            "version" => note.version
          }
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
      assert html =~ "Last sync:"
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
end
