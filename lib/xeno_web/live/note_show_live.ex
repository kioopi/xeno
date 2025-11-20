defmodule XenoWeb.NoteShowLive do
  use XenoWeb, :live_view

  alias Xeno.Content.Note
  require Logger

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Note.get(id) do
      {:ok, note} ->
        note = Ash.load!(note, [:directory, :note_type])

        if connected?(socket) do
          Logger.info("Socket connected; subscribing")
          Phoenix.PubSub.subscribe(Xeno.PubSub, "note:updated:#{note.id}")
          # Logger.info("Subscribed to note:#{id}:updated")
        else
          Logger.info("Socket not connected; skipping PubSub subscription")
        end

        {:ok, assign(socket, note: note, page_title: note.name)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Note not found")
         |> push_navigate(to: ~p"/")}
    end
  end


  @impl true
  def handle_info(%{topic: "note:updated:" <> _, payload: %{ id: id }}, socket) do
    note = Note.get!(id, load: [:directory, :note_type])

    {:noreply, assign(socket, note: note, page_title: note.name)}
  end

  @impl true
  def handle_event("edit", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/notes/#{socket.assigns.note.id}/edit")}
  end
end
