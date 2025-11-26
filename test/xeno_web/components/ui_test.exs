defmodule XenoWeb.Components.UITest do
  use XenoWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias XenoWeb.Components.UI

  describe "heading/1" do
    test "renders h1 with correct classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.heading level={1}>Title</UI.heading>
        """)

      assert html =~ ~r/<h1/
      assert html =~ ~r/text-3xl/
      assert html =~ ~r/font-bold/
      assert html =~ "Title"
    end

    test "renders h2 with correct classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.heading level={2}>Subtitle</UI.heading>
        """)

      assert html =~ ~r/<h2/
      assert html =~ ~r/text-2xl/
      assert html =~ ~r/font-semibold/
    end

    test "renders all heading levels correctly" do
      for level <- 1..6 do
        assigns = %{level: level}

        html =
          rendered_to_string(~H"""
          <UI.heading level={@level}>Heading</UI.heading>
          """)

        assert html =~ ~r/<h#{level}/
        assert html =~ "Heading"
      end
    end

    test "applies level-specific default styles" do
      test_cases = [
        {1, "text-3xl font-bold"},
        {2, "text-2xl font-semibold"},
        {3, "text-xl font-semibold"},
        {4, "text-lg font-semibold"},
        {5, "text-base font-semibold"},
        {6, "text-sm font-semibold"}
      ]

      for {level, expected_classes} <- test_cases do
        assigns = %{level: level}

        html =
          rendered_to_string(~H"""
          <UI.heading level={@level}>Test</UI.heading>
          """)

        Enum.each(String.split(expected_classes), fn class ->
          assert html =~ class
        end)
      end
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.heading level={1} class="custom-heading">Title</UI.heading>
        """)

      assert html =~ ~r/custom-heading/
    end

    test "passes through global attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.heading level={1} id="main-title" data-test="heading">Title</UI.heading>
        """)

      assert html =~ ~r/id="main-title"/
      assert html =~ ~r/data-test="heading"/
    end

    test "renders inner content correctly" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.heading level={1}>
          <span>Complex</span> <strong>Content</strong>
        </UI.heading>
        """)

      assert html =~ "Complex"
      assert html =~ "Content"
    end
  end

  describe "icon/1" do
    test "renders wa-icon with default variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.icon name="check-circle" />
        """)

      assert html =~ ~r/<wa-icon/
      assert html =~ ~r/name="check-circle"/
      assert html =~ ~r/variant="regular"/
    end

    test "renders with solid variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.icon name="star" variant={:solid} />
        """)

      assert html =~ ~r/variant="solid"/
    end

    test "renders all variants correctly" do
      variants = [:solid, :regular, :light, :thin, :duotone, :brands]

      for variant <- variants do
        assigns = %{variant: variant}

        html =
          rendered_to_string(~H"""
          <UI.icon name="icon" variant={@variant} />
          """)

        assert html =~ ~r/variant="#{variant}"/
      end
    end

    test "passes name attribute correctly" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.icon name="github" variant={:brands} />
        """)

      assert html =~ ~r/name="github"/
    end

    test "applies custom size via style attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.icon name="gear" size="2rem" />
        """)

      assert html =~ ~r/style="[^"]*font-size:\s*2rem/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.icon name="check" class="text-green-500" />
        """)

      assert html =~ ~r/class="[^"]*text-green-500/
    end
  end

  describe "button/1" do
    test "renders with default variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button>Click me</UI.button>
        """)

      assert html =~ ~r/<wa-button/
      assert html =~ ~r/variant="primary"/
      assert html =~ "Click me"
    end

    test "renders all variants correctly" do
      variants = [:primary, :secondary, :ghost, :soft]

      for variant <- variants do
        assigns = %{variant: variant}

        html =
          rendered_to_string(~H"""
          <UI.button variant={@variant}>Button</UI.button>
          """)

        assert html =~ ~r/variant="#{variant}"/
      end
    end

    test "renders all sizes correctly" do
      sizes = [:sm, :md, :lg]

      for size <- sizes do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <UI.button size={@size}>Button</UI.button>
          """)

        assert html =~ ~r/size="#{size}"/
      end
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button class="custom-btn">Button</UI.button>
        """)

      assert html =~ ~r/class="[^"]*custom-btn/
    end

    test "auto-generates id from phx-click when no id provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button phx-click="save_data">Save</UI.button>
        """)

      assert html =~ ~r/id="save-data-btn"/
    end

    test "respects explicit id" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button id="custom-id" phx-click="action">Button</UI.button>
        """)

      assert html =~ ~r/id="custom-id"/
      refute html =~ ~r/id="action-btn"/
    end

    test "converts underscores to hyphens in generated id" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button phx-click="export_all_notes">Export</UI.button>
        """)

      assert html =~ ~r/id="export-all-notes-btn"/
    end

    test "renders loading spinner when loading true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button loading>Loading...</UI.button>
        """)

      assert html =~ ~r/<wa-spinner/
      assert html =~ ~r/loading/
    end

    test "applies loading attribute when loading true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button loading>Button</UI.button>
        """)

      assert html =~ ~r/loading/
    end

    test "applies disabled attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button disabled>Button</UI.button>
        """)

      assert html =~ ~r/disabled/
    end

    test "passes through phx-click" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button phx-click="test_action">Button</UI.button>
        """)

      assert html =~ ~r/phx-click="test_action"/
    end

    test "passes through phx-value attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button phx-click="delete" phx-value-id="123">Delete</UI.button>
        """)

      assert html =~ ~r/phx-value-id="123"/
    end
  end

  describe "badge/1" do
    test "renders with default variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.badge>Active</UI.badge>
        """)

      assert html =~ ~r/<wa-tag/
      assert html =~ ~r/variant="primary"/
      assert html =~ "Active"
    end

    test "renders all variants correctly" do
      variants = [:primary, :success, :neutral, :warning, :danger]

      for variant <- variants do
        assigns = %{variant: variant}

        html =
          rendered_to_string(~H"""
          <UI.badge variant={@variant}>Badge</UI.badge>
          """)

        assert html =~ ~r/variant="#{variant}"/
      end
    end

    test "renders as pill when pill true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.badge pill>Pill Badge</UI.badge>
        """)

      assert html =~ ~r/pill/
    end

    test "renders as removable when removable true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.badge removable>Removable</UI.badge>
        """)

      assert html =~ ~r/removable/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.badge class="custom-badge">Badge</UI.badge>
        """)

      assert html =~ ~r/class="[^"]*custom-badge/
    end

    test "renders inner content correctly" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.badge>Complex <strong>Content</strong></UI.badge>
        """)

      assert html =~ "Complex"
      assert html =~ "Content"
    end
  end

  describe "spinner/1" do
    test "renders with default size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.spinner />
        """)

      assert html =~ ~r/<wa-spinner/
      assert html =~ ~r/style="[^"]*font-size:\s*1\.5rem/
    end

    test "renders all sizes correctly" do
      test_cases = [
        {:sm, "1rem"},
        {:md, "1.5rem"},
        {:lg, "2rem"}
      ]

      for {size, expected_size} <- test_cases do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <UI.spinner size={@size} />
          """)

        assert html =~ ~r/font-size:\s*#{Regex.escape(expected_size)}/
      end
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.spinner class="custom-spinner" />
        """)

      assert html =~ ~r/class="[^"]*custom-spinner/
    end
  end

  describe "divider/1" do
    test "renders horizontal by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.divider />
        """)

      assert html =~ ~r/<wa-divider/
      refute html =~ ~r/vertical/
    end

    test "renders vertical when vertical true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.divider vertical />
        """)

      assert html =~ ~r/vertical/
    end

    test "passes through custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.divider class="custom-divider" />
        """)

      assert html =~ ~r/class="[^"]*custom-divider/
    end
  end
end
