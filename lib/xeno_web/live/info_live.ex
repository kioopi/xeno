defmodule XenoWeb.InfoLive do
  use XenoWeb, :live_view

  alias Xeno.Files
  alias Xeno.Files.Directory
  require Ash.Query
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    notes_dir = Xeno.notes_dir()
    dirs = Files.tree!()

    # Subscribe to directory changes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:destroyed")
    else
      Logger.info("Socket not connected; skipping PubSub subscription")
    end

    {:ok, assign(socket, notes_dir: notes_dir, directories: dirs)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "directory:created",
          payload: %Phoenix.Socket.Broadcast{
            payload: %Ash.Notifier.Notification{
              data: directory
            }
          }
        },
        socket
      ) do
    {:noreply, update_directory_branch(socket, directory)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "directory:updated",
          payload: %Phoenix.Socket.Broadcast{
            payload: %Ash.Notifier.Notification{
              data: directory
            }
          }
        },
        socket
      ) do
    {:noreply, update_directory_branch(socket, directory)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "directory:moved"}, socket) do
    {:noreply, rebuild_entire_tree(socket)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "directory:destroyed"}, socket) do
    {:noreply, rebuild_entire_tree(socket)}
  end

  # Private helper functions

  defp update_directory_branch(socket, directory) do
    # Find which root this directory belongs to by loading the relationship
    directory_with_root = Ash.load!(directory, :root_ancestor)
    root = directory_with_root.root_ancestor

    # Rebuild just that branch
    new_branch = Files.branch!(root.id)

    # Update the tree
    updated_tree = Directory.Tree.update_tree(socket.assigns.directories, root.id, new_branch)

    assign(socket, directories: updated_tree)
  end

  defp rebuild_entire_tree(socket) do
    # Rebuild the entire tree from scratch
    updated_tree = Files.tree!()

    assign(socket, directories: updated_tree)
  end
end
