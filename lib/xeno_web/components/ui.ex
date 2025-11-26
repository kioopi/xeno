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
  attr :variant, :atom, default: :regular, values: [:solid, :regular, :light, :thin, :duotone, :brands]
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
    assigns = assign_new(assigns, :computed_id, fn ->
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
  attr :variant, :atom, default: :primary, values: [:primary, :success, :neutral, :warning, :danger]
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
end