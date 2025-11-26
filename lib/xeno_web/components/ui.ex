defmodule XenoWeb.Components.UI do
  @moduledoc """
  Provides UI components.
  """
  use Phoenix.Component

  @doc """
  Semantic heading component with level-based styling.

  ## Examples

      <.heading level={1}>Main Page Title</.heading>

      <.heading level={2} class="text-blue-600">Section Header</.heading>

      <.heading level={3} id="about">About Section</.heading>
  """
  attr :level, :integer, required: true, values: [1, 2, 3, 4, 5, 6]
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def heading(assigns) do
    ~H"""
    <.dynamic_tag tag_name={"h#{@level}"} class={[heading_classes(@level), @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </.dynamic_tag>
    """
  end

  defp heading_classes(1), do: "text-3xl font-bold"
  defp heading_classes(2), do: "text-2xl font-semibold"
  defp heading_classes(3), do: "text-xl font-semibold"
  defp heading_classes(4), do: "text-lg font-semibold"
  defp heading_classes(5), do: "text-base font-semibold"
  defp heading_classes(6), do: "text-sm font-semibold"

  @doc """
  Icon component that supports both hero icons and WebAwesome icons.

  Hero icons (legacy) use "hero-" prefix and render as CSS classes.
  Font Awesome icons render via WebAwesome wa-icon component.

  ## Examples

      <.icon name="hero-check" class="size-5" />

      <.icon name="check-circle" />

      <.icon name="star" variant={:solid} />

      <.icon name="gear" size="2rem" class="text-blue-500" />
  """
  attr :name, :string, required: true

  attr :variant, :atom,
    default: :regular,
    values: [:solid, :regular, :light, :thin, :duotone, :brands]

  attr :size, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end

  def icon(assigns) do
    ~H"""
    <wa-icon
      name={@name}
      variant={@variant}
      class={@class}
      style={@size && "font-size: #{@size}"}
      {@rest}
    />
    """
  end

  @doc """
  WebAwesome button component with auto test-id generation.

  ## Examples

      <.button>Click me</.button>

      <.button variant={:secondary} size={:lg}>Large Button</.button>

      <.button phx-click="save">Save</.button>

      <.button loading>Processing...</.button>
  """
  attr :variant, :atom, default: :primary, values: [:primary, :secondary, :ghost, :soft]
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :loading, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value-id id)
  slot :inner_block, required: true

  def button(assigns) do
    assigns =
      assign_new(assigns, :computed_id, fn ->
        Map.get(assigns.rest, :id) || generate_button_id(assigns.rest)
      end)

    ~H"""
    <wa-button
      id={@computed_id}
      variant={@variant}
      size={@size}
      loading={@loading && true}
      disabled={@disabled && true}
      class={@class}
      {@rest}
    >
      <%= if @loading do %>
        <wa-spinner slot="prefix" />
      <% end %>
      <%= render_slot(@inner_block) %>
    </wa-button>
    """
  end

  defp generate_button_id(%{"phx-click": action}) when is_binary(action) do
    action
    |> String.replace("_", "-")
    |> Kernel.<>("-btn")
  end

  defp generate_button_id(_), do: nil

  @doc """
  WebAwesome badge/tag component.

  ## Examples

      <.badge>Active</.badge>

      <.badge variant={:success}>Completed</.badge>

      <.badge pill removable>Tag</.badge>
  """
  attr :variant, :atom,
    default: :primary,
    values: [:primary, :success, :neutral, :warning, :danger]

  attr :pill, :boolean, default: false
  attr :removable, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <wa-tag
      variant={@variant}
      pill={@pill && true}
      removable={@removable && true}
      class={@class}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </wa-tag>
    """
  end

  @doc """
  WebAwesome spinner component for loading states.

  ## Examples

      <.spinner />

      <.spinner size={:lg} />

      <.spinner class="text-blue-500" />
  """
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil
  attr :rest, :global

  def spinner(assigns) do
    ~H"""
    <wa-spinner class={@class} style={"font-size: #{spinner_size(@size)}"} {@rest} />
    """
  end

  defp spinner_size(:sm), do: "1rem"
  defp spinner_size(:md), do: "1.5rem"
  defp spinner_size(:lg), do: "2rem"

  @doc """
  WebAwesome divider component for visual separation.

  ## Examples

      <.divider />

      <.divider vertical />

      <.divider class="my-8" />
  """
  attr :vertical, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def divider(assigns) do
    ~H"""
    <wa-divider vertical={@vertical && true} class={@class} {@rest} />
    """
  end

  @doc """
  WebAwesome card component for content containers.

  ## Examples

      <.card>
        Simple card content
      </.card>

      <.card title="Card Title" subtitle="Description">
        Card content
      </.card>

      <.card level={2} title="Section Title">
        Content with semantic heading
      </.card>

      <.card>
        <:header>
          <h2>Custom Header</h2>
        </:header>
        Main content
        <:actions>
          <.button>Save</.button>
        </:actions>
        <:footer>
          Footer content
        </:footer>
      </.card>
  """
  attr :level, :integer, default: nil
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :header, doc: "Custom header content (overrides title/subtitle)"
  slot :inner_block, required: true
  slot :footer, doc: "Footer content"
  slot :actions, doc: "Action buttons"

  def card(assigns) do
    ~H"""
    <wa-card class={@class} {@rest}>
      <%= if @header != [] do %>
        <%= render_slot(@header) %>
      <% else %>
        <%= if @title || @subtitle do %>
          <div slot="header">
            <%= if @title do %>
              <%= if @level do %>
                <.heading level={@level}><%= @title %></.heading>
              <% else %>
                <div class="font-semibold text-lg"><%= @title %></div>
              <% end %>
            <% end %>
            <%= if @subtitle do %>
              <div class="text-sm opacity-70"><%= @subtitle %></div>
            <% end %>
          </div>
        <% end %>
      <% end %>

      <%= render_slot(@inner_block) %>

      <%= if @actions != [] do %>
        <div slot="footer">
          <%= render_slot(@actions) %>
        </div>
      <% end %>

      <%= if @footer != [] do %>
        <div slot="footer">
          <%= render_slot(@footer) %>
        </div>
      <% end %>
    </wa-card>
    """
  end

  @doc """
  WebAwesome alert/callout component for status messages.

  ## Examples

      <.alert>
        Information message
      </.alert>

      <.alert variant={:success}>
        Success message
      </.alert>

      <.alert variant={:danger} closable>
        Error message with close button
      </.alert>

      <.alert variant={:warning}>
        <:icon><.icon name="exclamation-triangle" /></:icon>
        Custom icon alert
      </.alert>
  """
  attr :variant, :atom,
    default: :info,
    values: [:info, :success, :warning, :danger, :brand]

  attr :closable, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global
  slot :icon, doc: "Custom icon (defaults to variant icon)"
  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <wa-callout variant={@variant} closable={@closable && true} class={@class} {@rest}>
      <%= if @icon != [] do %>
        <%= render_slot(@icon) %>
      <% end %>
      <%= render_slot(@inner_block) %>
    </wa-callout>
    """
  end

  @doc """
  Page header component with title, subtitle, and actions.

  ## Examples

      <.page_header title="Page Title" />

      <.page_header level={2} title="Section Title" subtitle="Description" />

      <.page_header title="Note Title">
        <:actions>
          <.button>Edit</.button>
          <.button>Delete</.button>
        </:actions>
      </.page_header>
  """
  attr :level, :integer, default: 1
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :actions, doc: "Action buttons"

  def page_header(assigns) do
    ~H"""
    <div class={["flex items-start justify-between gap-4 mb-6", @class]} {@rest}>
      <div class="flex-1">
        <.heading level={@level}><%= @title %></.heading>
        <%= if @subtitle do %>
          <p class="text-sm opacity-70 mt-2"><%= @subtitle %></p>
        <% end %>
      </div>
      <%= if @actions != [] do %>
        <div class="flex gap-2 shrink-0">
          <%= render_slot(@actions) %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Container for grouping related action buttons.

  ## Examples

      <.button_group>
        <.button>Save</.button>
        <.button variant={:ghost}>Cancel</.button>
      </.button_group>

      <.button_group gap={:l}>
        <.button>Action 1</.button>
        <.button>Action 2</.button>
      </.button_group>
  """
  attr :gap, :atom, default: :m, values: [:s, :m, :l]
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def button_group(assigns) do
    ~H"""
    <div class={["flex", button_group_gap(@gap), @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  defp button_group_gap(:s), do: "gap-1"
  defp button_group_gap(:m), do: "gap-2"
  defp button_group_gap(:l), do: "gap-4"

  @doc """
  Renders a list of tags/badges.

  ## Examples

      <.tag_list tags={["elixir", "phoenix"]} />

      <.tag_list tags={@note.tags} variant={:success} />

      <.tag_list tags={[]} class="my-4" />
  """
  attr :tags, :list, required: true

  attr :variant, :atom,
    default: :primary,
    values: [:primary, :success, :neutral, :warning, :danger]

  attr :class, :string, default: nil
  attr :rest, :global

  def tag_list(assigns) do
    ~H"""
    <div class={["flex flex-wrap gap-2", @class]} {@rest}>
      <%= for tag <- @tags do %>
        <.badge variant={@variant}><%= tag %></.badge>
      <% end %>
    </div>
    """
  end

  @doc """
  Display formatted code or preformatted text.

  ## Examples

      <.code_block content="const x = 42;" />

      <.code_block content={@code} language="elixir" />

      <.code_block content={Jason.encode!(@data, pretty: true)} language="json" />
  """
  attr :content, :string, required: true
  attr :language, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def code_block(assigns) do
    ~H"""
    <wa-card class={@class} {@rest}>
      <pre class="overflow-x-auto">
        <code class={@language && "language-#{@language}"}>
          <%= @content %>
        </code>
      </pre>
    </wa-card>
    """
  end
end
