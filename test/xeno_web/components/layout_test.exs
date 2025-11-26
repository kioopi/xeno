defmodule XenoWeb.Components.LayoutTest do
  use XenoWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias XenoWeb.Components.Layout

  describe "container/1" do
    test "renders with default max_width" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.container>Content</Layout.container>
        """)

      assert html =~ ~r/max-w-xl/
      assert html =~ ~r/mx-auto/
      assert html =~ ~r/px-4/
      assert html =~ ~r/py-8/
      assert html =~ "Content"
    end

    test "renders with custom max_width" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.container max_width={:lg}>Content</Layout.container>
        """)

      assert html =~ ~r/max-w-lg/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.container class="custom-class">Content</Layout.container>
        """)

      assert html =~ ~r/custom-class/
    end

    test "renders full width when max_width is :full" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.container max_width={:full}>Content</Layout.container>
        """)

      refute html =~ ~r/max-w-/
    end
  end

  describe "stack/1" do
    test "renders with default gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.stack><div>Item 1</div><div>Item 2</div></Layout.stack>
        """)

      assert html =~ ~r/wa-stack/
      assert html =~ ~r/wa-gap-m/
      assert html =~ "Item 1"
      assert html =~ "Item 2"
    end

    test "renders with custom gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.stack gap={:xl}>Content</Layout.stack>
        """)

      assert html =~ ~r/wa-gap-xl/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.stack class="my-custom-stack">Content</Layout.stack>
        """)

      assert html =~ ~r/my-custom-stack/
    end

    test "renders all gap sizes correctly" do
      for gap <- [:s, :m, :l, :xl] do
        assigns = %{gap: gap}

        html =
          rendered_to_string(~H"""
          <Layout.stack gap={@gap}>Content</Layout.stack>
          """)

        assert html =~ ~r/wa-gap-#{gap}/
      end
    end
  end

  describe "grid/1" do
    test "renders with default min_column_size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.grid>Content</Layout.grid>
        """)

      assert html =~ ~r/wa-grid/
      assert html =~ ~r/--min-column-size:\s*20ch/
    end

    test "renders with custom min_column_size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.grid min_column_size="300px">Content</Layout.grid>
        """)

      assert html =~ ~r/--min-column-size:\s*300px/
    end

    test "renders with custom gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.grid gap={:l}>Content</Layout.grid>
        """)

      assert html =~ ~r/wa-gap-l/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.grid class="custom-grid">Content</Layout.grid>
        """)

      assert html =~ ~r/custom-grid/
    end
  end

  describe "split/1" do
    test "renders horizontal split by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.split>Content</Layout.split>
        """)

      assert html =~ ~r/wa-split/
      refute html =~ ~r/wa-split-vertical/
    end

    test "renders vertical split when specified" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.split direction={:vertical}>Content</Layout.split>
        """)

      assert html =~ ~r/wa-split-vertical/
    end

    test "renders with custom gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.split gap={:xl}>Content</Layout.split>
        """)

      assert html =~ ~r/wa-gap-xl/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.split class="custom-split">Content</Layout.split>
        """)

      assert html =~ ~r/custom-split/
    end
  end

  describe "flank/1" do
    test "renders with default gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.flank>Content</Layout.flank>
        """)

      assert html =~ ~r/wa-flank/
      assert html =~ ~r/wa-gap-m/
    end

    test "renders with custom gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.flank gap={:s}>Content</Layout.flank>
        """)

      assert html =~ ~r/wa-gap-s/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Layout.flank class="custom-flank">Content</Layout.flank>
        """)

      assert html =~ ~r/custom-flank/
    end
  end
end
