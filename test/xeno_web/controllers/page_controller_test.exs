defmodule XenoWeb.PageControllerTest do
  use XenoWeb.ConnCase

  setup do
    Xeno.Files.Directory.create!("test/root", %{name: "root"})
    :ok
  end

  # this is actually not loading PageController but StartLive
  # We'll leave it like that for now. There might be pages in the future.
  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Xeno"
  end
end
