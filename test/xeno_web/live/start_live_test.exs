defmodule XenoWeb.StartLiveTest do
  use XenoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Xeno.Generators

  setup do
    note_type = generate(note_type(name: "Doc"))

    projects = Xeno.Files.Directory.create!("projects")
    alpha = Xeno.Files.Directory.create!("projects/alpha")
    _empty = Xeno.Files.Directory.create!("empty")

    note =
      generate(
        note(
          name: "Alpha Note",
          directory_id: alpha.id,
          note_type_id: note_type.id
        )
      )

    {:ok, note: note, projects: projects, alpha: alpha}
  end

  describe "navigation" do
    test "links to other pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='/info']", "Info")
      assert has_element?(view, "a[href='/sync']", "Sync")
    end
  end

  describe "note tree" do
    test "shows only directories with notes and all are expanded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "wa-tree-item[expanded]", "Projects")
      assert has_element?(view, "wa-tree-item[expanded]", "Alpha")

      refute has_element?(view, "summary", "Empty")
    end

    test "renders notes as links to NoteShowLive", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='/notes/#{note.id}']", note.name)
    end
  end
end
