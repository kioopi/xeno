defmodule XenoWeb.PageControllerTest do
  use XenoWeb.ConnCase

  setup do
    notes_dir = Xeno.notes_dir()
    Xeno.Files.Directory.create!(notes_dir, %{name: "root"})
    :ok
  end

  # this is actually not loading PageController but InfoLive
  # We'll leave it like that for now. There might be pages in the future.
  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Xeno"
  end
end
