defmodule XenoWeb.InfoLiveTest do
  use XenoWeb.ConnCase

  import Phoenix.LiveViewTest

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
