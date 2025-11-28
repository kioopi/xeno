defmodule XenoWeb.StartLive do
  use XenoWeb, :live_view

  alias Xeno.Files.NoteTree

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Xeno Start",
       note_tree: NoteTree.build()
     )}
  end
end
