defmodule XenoWeb.RouterTest do
  use XenoWeb.ConnCase, async: true

  test "note show route exists" do
    route =
      XenoWeb.Router.__routes__()
      |> Enum.find(&(&1.path == "/notes/:id"))

    assert route
    assert route.metadata.log_module == XenoWeb.NoteShowLive
  end

  test "note edit route exists" do
    route =
      XenoWeb.Router.__routes__()
      |> Enum.find(&(&1.path == "/notes/:id/edit"))

    assert route
    assert route.metadata.log_module == XenoWeb.NoteEditLive
  end

  test "start page route exists at root" do
    route =
      XenoWeb.Router.__routes__()
      |> Enum.find(&(&1.path == "/"))

    assert route
    assert route.metadata.log_module == XenoWeb.StartLive
  end

  test "info route exists at /info" do
    route =
      XenoWeb.Router.__routes__()
      |> Enum.find(&(&1.path == "/info"))

    assert route
    assert route.metadata.log_module == XenoWeb.InfoLive
  end
end
