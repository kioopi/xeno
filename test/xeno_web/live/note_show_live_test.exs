defmodule XenoWeb.NoteShowLiveTest do
  use XenoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Xeno.Generators

  alias Xeno.Content.Note

  setup do
    directory = generate(directory(path: "test_notes"))

    note_type =
      generate(
        note_type(
          name: "Test Type",
          initial_text: "Initial content",
          initial_tags: ["initial"]
        )
      )

    note =
      generate(
        note(
          name: "Test Note",
          text: "Test content here",
          data: %{"key" => "value", "number" => 42},
          tags: ["test", "example"],
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

    {:ok, note: note, directory: directory, note_type: note_type}
  end

  describe "mount and display" do
    test "mounts and displays note name", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert has_element?(view, "h1", note.name)
    end

    test "displays note type and directory information", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ note.note_type.name
      assert render(view) =~ note.directory.path
    end

    test "displays version number", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "Version: 1"
    end

    test "displays text content in formatted block", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "Test content here"
      assert has_element?(view, "pre", "Test content here")
    end

    test "displays tags", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "test"
      assert render(view) =~ "example"
    end

    test "displays JSON data formatted", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      html = render(view)
      assert html =~ "Data"
      assert html =~ "value"
    end

    test "displays timestamps", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      html = render(view)
      assert html =~ "Created:"
      assert html =~ "Updated:"
    end

    test "shows Edit button", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert has_element?(view, "button", "Edit")
    end

    test "redirects when note not found", %{conn: conn} do
      fake_id = Ash.UUID.generate()

      assert {:error, {:live_redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/notes/#{fake_id}")

      assert flash["error"] =~ "Note not found"
    end

    test "preloads directory and note_type relationships", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      html = render(view)
      assert html =~ note.note_type.name
      assert html =~ note.directory.path
    end
  end

  describe "navigation" do
    test "clicking Edit button navigates to edit page", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      view
      |> element("button", "Edit")
      |> render_click()

      assert_redirect(view, ~p"/notes/#{note.id}/edit")
    end
  end

  describe "PubSub auto-updates" do
    test "auto-updates name when note changes", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert has_element?(view, "h1", "Test Note")

      {:ok, _updated} = Note.update(note, %{name: "Updated Name"})

      :timer.sleep(200)

      assert has_element?(view, "h1", "Updated Name")
    end

    test "auto-updates text when note changes", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "Test content here"

      {:ok, _updated} = Note.update(note, %{text: "Brand new content"})

      :timer.sleep(200)

      assert render(view) =~ "Brand new content"
    end

    test "auto-updates tags when note changes", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "test"
      assert render(view) =~ "example"

      {:ok, _updated} = Note.update(note, %{tags: ["updated", "tags"]})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "updated"
      assert html =~ "tags"
    end

    test "auto-updates data when note changes", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "value"

      {:ok, _updated} = Note.update(note, %{data: %{"newkey" => "newvalue"}})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "newkey"
      assert html =~ "newvalue"
    end

    test "increments version number on update", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}")

      assert render(view) =~ "Version: 1"

      {:ok, _updated} = Note.update(note, %{text: "Updated"})

      :timer.sleep(200)

      assert render(view) =~ "Version: 2"
    end
  end
end
