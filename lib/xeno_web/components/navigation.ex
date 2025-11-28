defmodule XenoWeb.Components.Navigation do
  @moduledoc """
  Components to create navigation bars or menu.
  """
  # use Phoenix.Component
  use XenoWeb, :html
  use Gettext, backend: XenoWeb.Gettext

  # alias Phoenix.LiveView.JS

  @doc """
  Renders a directory tree

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :directories, :list, required: true
  attr :class, :string, default: ""

  def file_tree(assigns) do
    ~H"""
    <ul class="menu menu-xs bg-base-200 rounded-box max-w-xs w-full">
      <.directory
        :for={{directory, children} <- @directories}
        directory={directory}
        children={children}
      />
    </ul>
    """
  end

  @doc """
  Renders a WebAwesome-based directory tree

  ## Examples

      <.webawesome_file_tree directories={@directories} />
  """
  attr :directories, :list, required: true
  attr :class, :string, default: ""

  def webawesome_file_tree(assigns) do
    ~H"""
    <wa-tree id="webawesome-directory-tree" class="w-full">
      <.webawesome_tree_item
        :for={{directory, children} <- @directories}
        directory={directory}
        children={children}
      />
    </wa-tree>
    """
  end

  @doc """
  Renders a single WebAwesome tree item with recursive children
  """
  attr :directory, :any, required: true
  attr :children, :list, default: []

  def webawesome_tree_item(assigns) do
    ~H"""
    <wa-tree-item expanded>
      <wa-icon name="folder" slot="expand-icon"></wa-icon>
      <wa-icon name="folder-open" slot="collapse-icon"></wa-icon>
      {@directory.name}
      <.webawesome_tree_item
        :for={{child_dir, child_children} <- @children}
        directory={child_dir}
        children={child_children}
      />
    </wa-tree-item>
    """
  end

  attr :directory, :any, required: true
  attr :children, :list, default: []
  attr :class, :string, default: nil

  def directory(%{directory: directory, class: class} = assigns) do
    group = "#{directory.filename}"

    assigns =
      assign(assigns, :class, Enum.join([class, "group/#{group}"], " "))
      |> assign(:group, group)

    ~H"""
    <li class="directory mb-2">
      <details open class={@class}>
        <summary>
          <.icon name="hero-folder" class="h-4 w-4 icon" />
          <.icon name="hero-folder-open" class="h-4 w-4 icon-open" />
          {@directory.name}
        </summary>
        <ul>
          <.directory
            :for={{directory, children} <- @children}
            directory={directory}
            children={children}
          />
        </ul>
      </details>
    </li>
    """
  end

  @doc """
  Renders a directory tree with notes, showing only branches that contain notes.

  Expects each directory to carry a `:notes` key with its notes.
  """
  attr :directories, :list, required: true
  attr :class, :string, default: nil

  def note_tree(assigns) do
    ~H"""
    <wa-tree id="webawesome-directory-tree" class="custom-icons">
      <.note_directory
        :for={{directory, children} <- @directories}
        directory={directory}
        children={children}
      />
    </wa-tree>
    """
  end

  attr :directory, :any, required: true
  attr :children, :list, default: []
  attr :class, :string, default: nil

  def note_directory(assigns) do
    notes = Map.get(assigns.directory, :notes, [])

    assigns =
      assigns
      |> assign(:notes, notes)

    ~H"""
    <wa-tree-item expanded>
      <wa-icon name="folder" slot="expand-icon"></wa-icon>
      <wa-icon name="folder-open" slot="collapse-icon"></wa-icon>
      {@directory.name}

      <wa-tree-item :for={note <- @notes}>
        <.link navigate={~p"/notes/#{note.id}"}>
          <.icon name="file" />
          {note.name}
        </.link>
      </wa-tree-item>

      <.note_directory
        :for={{child_dir, child_children} <- @children}
        directory={child_dir}
        children={child_children}
      />
    </wa-tree-item>
    """
  end
end
