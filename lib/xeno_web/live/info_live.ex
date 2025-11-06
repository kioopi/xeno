defmodule XenoWeb.InfoLive do
  use XenoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    notes_dir = Xeno.notes_dir()

    {:ok, assign(socket, root_dir: root_dir)}
  end
end
