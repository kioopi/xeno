defmodule XenoWeb.InfoLive do
  use XenoWeb, :live_view

  alias Xeno.Files.Directory
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    notes_dir = Xeno.notes_dir()
    dirs = Directory.Tree.build()

    {:ok, assign(socket, notes_dir: notes_dir, directories: dirs)}
  end
end
