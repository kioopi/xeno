defmodule XenoWeb.InfoLive do
  use XenoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, notes_dir: Xeno.notes_dir())}
  end
end
