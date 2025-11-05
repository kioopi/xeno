defmodule XenoWeb.PageController do
  use XenoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
