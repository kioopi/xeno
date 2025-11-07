defmodule XenoWeb.InfoLiveTest do
  use XenoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    notes_dir = Xeno.notes_dir()
    Xeno.Files.Directory.create!(notes_dir, %{name: "root"})
    # Xeno.Files.create_directories_from_filesystem!(notes_dir)
    :ok
  end

  test "displays Xeno installation information", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "h1", "Xeno Installation Information")
  end

  test "displays the notes directory path", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert view |> element("dd") |> render() =~ Xeno.notes_dir()

    assert has_element?(view, "dd", Xeno.notes_dir())
  end
end
