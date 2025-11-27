defmodule XenoWeb.Components.Layout do
  @moduledoc """
  Layout components for consistent spacing and positioning.

  These components wrap WebAwesome CSS utility classes to provide
  semantic layout primitives.
  """

  use Phoenix.Component

  @doc """
  Page-level content wrapper with responsive max-width.

  ## Examples

      <.container>
        Page content here
      </.container>

      <.container max_width={:lg}>
        Narrower content
      </.container>

      <.container max_width={:full}>
        Full width content
      </.container>
  """
  attr :max_width, :atom, default: :xl, values: [:sm, :md, :lg, :xl, :full]
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div class={[
      max_width_class(@max_width),
      "mx-auto px-4 py-8",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp max_width_class(:full), do: nil
  defp max_width_class(size), do: "max-w-#{size}"

  @doc """
  Vertical layout with consistent spacing between children.

  ## Examples

      <.stack>
        <div>Item 1</div>
        <div>Item 2</div>
        <div>Item 3</div>
      </.stack>

      <.stack gap={:xl}>
        Content with extra large gaps
      </.stack>
  """
  attr :gap, :atom, default: :m, values: [:xxxs, :xxs, :xs, :s, :m, :l, :xl, :xxl, :xxxl]
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def stack(assigns) do
    ~H"""
    <div class={["wa-stack", "wa-gap-#{gap_class(@gap)}", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Responsive auto-grid layout.

  ## Examples

      <.grid>
        <.card>Card 1</.card>
        <.card>Card 2</.card>
        <.card>Card 3</.card>
      </.grid>

      <.grid min_column_size="300px" gap={:l}>
        Wider columns with larger gaps
      </.grid>
  """
  attr :min_column_size, :string, default: "20ch"
  attr :gap, :atom, default: :m, values: [:xxxs, :xxs, :xs, :s, :m, :l, :xl, :xxl, :xxxl]
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def grid(assigns) do
    ~H"""
    <div
      class={["wa-grid", "wa-gap-#{gap_class(@gap)}", @class]}
      style={"--min-column-size: #{@min_column_size}"}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Distribute items evenly across space (horizontal or vertical).

  ## Examples

      <.split>
        <div>Left content</div>
        <div>Right content</div>
      </.split>

      <.split direction={:vertical} gap={:xl}>
        <div>Top content</div>
        <div>Bottom content</div>
      </.split>
  """
  attr :direction, :atom, default: :horizontal, values: [:horizontal, :vertical]
  attr :gap, :atom, default: :m, values: [:xxxs, :xxs, :xs, :s, :m, :l, :xl, :xxl, :xxxl]
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def split(assigns) do
    ~H"""
    <div class={[
      "wa-split",
      @direction == :vertical && "wa-split-vertical",
      "wa-gap-#{gap_class(@gap)}",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Icon/avatar + text layout (one item flanks another that fills space).

  ## Examples

      <.flank>
        <.icon name="check-circle" />
        <span>Operation successful</span>
      </.flank>

      <.flank gap={:s}>
        <img src="avatar.jpg" />
        <span>User name</span>
      </.flank>
  """
  attr :gap, :atom, default: :m, values: [:xxxs, :xxs, :xs, :s, :m, :l, :xl, :xxl, :xxxl]
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def flank(assigns) do
    ~H"""
    <div class={["wa-flank", "wa-gap-#{gap_class(@gap)}", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp gap_class(:xxxs), do: "3xs"
  defp gap_class(:xxs), do: "2xs"
  defp gap_class(:xxxl), do: "3xl"
  defp gap_class(:xxl), do: "2xl"
  defp gap_class(gap), do: to_string(gap)
end
