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

  describe "card/1" do
    test "renders with default slot content only" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card>
          <p>Card content here</p>
        </UI.card>
        """)

      assert html =~ ~r/<wa-card/
      assert html =~ "Card content here"
    end

    test "renders with title attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card title="Card Title">
          Content
        </UI.card>
        """)

      assert html =~ "Card Title"
      assert html =~ "Content"
    end

    test "renders with title and subtitle attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card title="Main Title" subtitle="Description text">
          Content
        </UI.card>
        """)

      assert html =~ "Main Title"
      assert html =~ "Description text"
      assert html =~ "Content"
    end

    test "renders title as heading when level provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card level={2} title="Section Title">
          Content
        </UI.card>
        """)

      assert html =~ ~r/<h2[^>]*>/
      assert html =~ "Section Title"
      assert html =~ ~r/<\/h2>/
    end

    test "renders title as plain text when no level provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card title="Plain Title">
          Content
        </UI.card>
        """)

      assert html =~ "Plain Title"
      refute html =~ ~r/<h[1-6]/
    end

    test "uses correct heading level for title" do
      for level <- 1..6 do
        assigns = %{level: level}

        html =
          rendered_to_string(~H"""
          <UI.card level={@level} title="Title">
            Content
          </UI.card>
          """)

        assert html =~ ~r/<h#{level}[^>]*>/
        assert html =~ "Title"
        assert html =~ ~r/<\/h#{level}>/
      end
    end

    test "renders custom header slot overriding title" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card title="Ignored Title">
          <:header>
            <div class="custom-header">Custom Header Content</div>
          </:header>
          Main content
        </UI.card>
        """)

      assert html =~ "Custom Header Content"
      assert html =~ "custom-header"
      assert html =~ "Main content"
      refute html =~ "Ignored Title"
    end

    test "renders footer slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card>
          Main content
          <:footer>
            <p>Footer content</p>
          </:footer>
        </UI.card>
        """)

      assert html =~ "Main content"
      assert html =~ "Footer content"
    end

    test "renders actions slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card title="Card with actions">
          Content
          <:actions>
            <button>Action 1</button>
            <button>Action 2</button>
          </:actions>
        </UI.card>
        """)

      assert html =~ "Action 1"
      assert html =~ "Action 2"
    end

    test "handles multiple slots together" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card>
          <:header>
            <h2>Custom Header</h2>
          </:header>
          Main content
          <:actions>
            <button>Action</button>
          </:actions>
          <:footer>
            Footer text
          </:footer>
        </UI.card>
        """)

      assert html =~ "Custom Header"
      assert html =~ "Main content"
      assert html =~ "Action"
      assert html =~ "Footer text"
    end

    test "inner block renders correctly with all slots" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card title="Title">
          <:actions><button>Save</button></:actions>
          <p>Paragraph 1</p>
          <p>Paragraph 2</p>
          <:footer>Footer</:footer>
        </UI.card>
        """)

      assert html =~ "Paragraph 1"
      assert html =~ "Paragraph 2"
      assert html =~ "Save"
      assert html =~ "Footer"
    end

    test "applies custom class attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card class="custom-card">
          Content
        </UI.card>
        """)

      assert html =~ ~r/class="[^"]*custom-card/
    end

    test "passes through rest attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card id="my-card" data-test="card-element">
          Content
        </UI.card>
        """)

      assert html =~ ~r/id="my-card"/
      assert html =~ ~r/data-test="card-element"/
    end

    test "wraps with wa-card element" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.card>Content</UI.card>
        """)

      assert html =~ ~r/<wa-card/
      assert html =~ ~r/<\/wa-card>/
    end
  end

  describe "alert/1" do
    test "renders with default info variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert>
          Information message
        </UI.alert>
        """)

      assert html =~ ~r/<wa-callout/
      assert html =~ ~r/variant="info"/
      assert html =~ "Information message"
    end

    test "renders success variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert variant={:success}>
          Success message
        </UI.alert>
        """)

      assert html =~ ~r/variant="success"/
    end

    test "renders warning variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert variant={:warning}>
          Warning message
        </UI.alert>
        """)

      assert html =~ ~r/variant="warning"/
    end

    test "renders danger variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert variant={:danger}>
          Error message
        </UI.alert>
        """)

      assert html =~ ~r/variant="danger"/
    end

    test "renders brand variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert variant={:brand}>
          Brand message
        </UI.alert>
        """)

      assert html =~ ~r/variant="brand"/
    end

    test "renders without closable by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert>Message</UI.alert>
        """)

      refute html =~ ~r/closable/
    end

    test "renders as closable when closable true" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert closable>
          Closable message
        </UI.alert>
        """)

      assert html =~ ~r/closable/
    end

    test "renders without icon slot by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert>Message</UI.alert>
        """)

      assert html =~ "Message"
    end

    test "renders custom icon slot when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert variant={:danger}>
          <:icon><UI.icon name="exclamation-triangle" /></:icon>
          Custom icon message
        </UI.alert>
        """)

      assert html =~ "exclamation-triangle"
      assert html =~ "Custom icon message"
    end

    test "applies custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.alert class="custom-alert">
          Message
        </UI.alert>
        """)

      assert html =~ ~r/class="[^"]*custom-alert/
    end
  end

  describe "page_header/1" do
    test "renders title with default level 1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.page_header title="Page Title" />
        """)

      assert html =~ ~r/<h1/
      assert html =~ "Page Title"
    end

    test "renders title with custom level" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.page_header level={2} title="Section Title" />
        """)

      assert html =~ ~r/<h2/
      assert html =~ "Section Title"
    end

    test "uses heading component for semantic HTML" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.page_header level={3} title="Subsection" />
        """)

      assert html =~ ~r/<h3[^>]*class="[^"]*text-xl/
      assert html =~ "Subsection"
    end

    test "renders optional subtitle" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.page_header title="Title" subtitle="Description text" />
        """)

      assert html =~ "Title"
      assert html =~ "Description text"
    end

    test "renders without actions slot" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.page_header title="Title" />
        """)

      assert html =~ "Title"
    end

    test "renders actions slot with buttons" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.page_header title="Title">
          <:actions>
            <button>Edit</button>
            <button>Delete</button>
          </:actions>
        </UI.page_header>
        """)

      assert html =~ "Title"
      assert html =~ "Edit"
      assert html =~ "Delete"
    end
  end

  describe "button_group/1" do
    test "renders children with default gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button_group>
          <button>Save</button>
          <button>Cancel</button>
        </UI.button_group>
        """)

      assert html =~ "Save"
      assert html =~ "Cancel"
      assert html =~ ~r/flex/
      assert html =~ ~r/gap-2/
    end

    test "renders children with custom gap" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button_group gap={:s}>
          <button>Button</button>
        </UI.button_group>
        """)

      assert html =~ ~r/gap-1/
    end

    test "uses flex layout" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button_group>
          <button>Button</button>
        </UI.button_group>
        """)

      assert html =~ ~r/flex/
    end

    test "applies custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.button_group class="custom-group">
          <button>Button</button>
        </UI.button_group>
        """)

      assert html =~ ~r/custom-group/
    end
  end

  describe "tag_list/1" do
    test "renders empty state for empty list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.tag_list tags={[]} />
        """)

      assert html =~ ~r/<div/
    end

    test "renders badge for each tag" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.tag_list tags={["elixir", "phoenix", "liveview"]} />
        """)

      assert html =~ "elixir"
      assert html =~ "phoenix"
      assert html =~ "liveview"
      assert html =~ ~r/<wa-tag/
    end

    test "applies variant to all badges" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.tag_list tags={["tag1", "tag2"]} variant={:success} />
        """)

      assert html =~ ~r/variant="success"/
    end

    test "uses default primary variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.tag_list tags={["tag"]} />
        """)

      assert html =~ ~r/variant="primary"/
    end

    test "applies custom class to container" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.tag_list tags={["tag"]} class="custom-tags" />
        """)

      assert html =~ ~r/custom-tags/
    end
  end

  describe "code_block/1" do
    test "renders content in pre code structure" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.code_block content="const x = 42;" />
        """)

      assert html =~ ~r/<pre/
      assert html =~ ~r/<code/
      assert html =~ "const x = 42;"
    end

    test "escapes HTML content properly" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.code_block content="<div>test</div>" />
        """)

      assert html =~ "&lt;div&gt;test&lt;/div&gt;"
    end

    test "renders without language class by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.code_block content="code here" />
        """)

      assert html =~ "code here"
      refute html =~ ~r/language-/
    end

    test "applies language class when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.code_block content="code" language="elixir" />
        """)

      assert html =~ ~r/language-elixir/
    end

    test "applies custom class to wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <UI.code_block content="code" class="custom-code" />
        """)

      assert html =~ ~r/custom-code/
    end
  end
end
