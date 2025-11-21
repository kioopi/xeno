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
        |> element("#export-all-btn")
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
        |> element("#export-all-btn")
        |> render_click()

      assert html =~ "2 notes"
    end
  end
end
