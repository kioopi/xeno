defmodule XenoWeb.InfoLive do
  use XenoWeb, :live_view

  alias Xeno.Files.Directory
  require Ash.Query
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    notes_dir = Xeno.notes_dir()
    dirs = Directory.Tree.build()

    # Subscribe to directory changes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
    else
      Logger.info("Socket not connected; skipping PubSub subscription")
    end

    {:ok, assign(socket, notes_dir: notes_dir, directories: dirs)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "directory:created",
          event: "create",
          payload: %Phoenix.Socket.Broadcast{
            payload: %Ash.Notifier.Notification{
              data: created_dir
            }
          }
        },
        socket
      ) do
    # Find which root this directory belongs to
    root = Directory.Tree.find_root_ancestor(created_dir)

    # Rebuild just that branch
    new_branch = Directory.Tree.build_branch(root.id)

    # Update the tree
    updated_tree = Directory.Tree.update_tree(socket.assigns.directories, root.id, new_branch)

    {:noreply, assign(socket, directories: updated_tree)}
  end
end
