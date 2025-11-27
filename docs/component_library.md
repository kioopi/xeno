# Component Library

Xeno uses a custom component library built on top of [WebAwesome](https://webawesome.com/) and Tailwind CSS. This library provides a declarative, semantic approach to building user interfaces while maintaining consistency across the application.

## Overview

The component library consists of two main modules:

- **`XenoWeb.Components.Layout`** - Layout primitives for spacing and positioning (container, stack, grid, split, flank)
- **`XenoWeb.Components.UI`** - UI components for interactive elements (buttons, cards, alerts, modals, etc.)

All components are automatically available in LiveView templates through `XenoWeb.html_helpers/0`.

## Core Principles

### 1. Declarative Over Imperative

Templates should describe **what** things are, not **how** they look.

**❌ Don't do this (imperative, class-heavy):**

```heex
<div class="max-w-7xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-8">Page Title</h1>
  <div class="space-y-6">
    <div class="card bg-base-200">
      <div class="card-body">
        Content here
      </div>
    </div>
  </div>
</div>
```

**✅ Do this (declarative, semantic):**

```heex
<.container>
  <.stack gap={:xl}>
    <.heading level={1}>Page Title</.heading>
    <.card>
      Content here
    </.card>
  </.stack>
</.container>
```

### 2. Semantic HTML Structure

The component library enforces proper semantic HTML, particularly for heading hierarchy. Use the `level` prop to maintain correct document structure:

```heex
<.container>
  <.heading level={1}>Main Title</.heading>

  <.card level={2} title="Section">
    <%!-- Card automatically renders title as <h2> --%>
    Content here
  </.card>
</.container>
```

### 3. Single Source of Truth

Each UI pattern is defined once in the component library and reused everywhere. This eliminates code duplication and ensures consistency.

### 4. Auto-Generated Test IDs

Buttons with `phx-click` events automatically generate test IDs:

```heex
<.button phx-click="save_data">Save</.button>
<%!-- Automatically generates id="save-data-btn" --%>
```

This makes testing easier without manual ID management.

## Available Components

### Layout Components

#### `<.container>`

Page-level wrapper with responsive max-width.

```heex
<.container>Content</.container>
<.container max_width={:lg}>Narrower content</.container>
```

#### `<.stack>`

Vertical layout with consistent spacing.

```heex
<.stack gap={:xl}>
  <div>Item 1</div>
  <div>Item 2</div>
</.stack>
```

#### `<.grid>`

Responsive auto-grid layout.

```heex
<.grid min_column_size="300px" gap={:l}>
  <.card>Card 1</.card>
  <.card>Card 2</.card>
</.grid>
```

#### `<.split>`

Distribute items evenly across space.

```heex
<.split gap={:m}>
  <div>Left</div>
  <div>Right</div>
</.split>
```

#### `<.flank>`

Icon/avatar + text layout (one item flanks another that fills space).

```heex
<.flank gap={:s}>
  <.icon name="check-circle" />
  <span>Operation successful</span>
</.flank>
```

### UI Components

#### `<.heading>`

Semantic headings with level-based styling.

```heex
<.heading level={1}>Main Title</.heading>
<.heading level={2}>Subsection</.heading>
```

#### `<.icon>`

Icons using Font Awesome (via WebAwesome).

```heex
<.icon name="check-circle" />
<.icon name="gear" variant={:solid} size="1.5rem" />
```

#### `<.button>`

Action buttons with variants, appearances, and loading states.

```heex
<.button phx-click="save" variant={:brand} appearance={:filled}>Save</.button>
<.button phx-click="cancel" variant={:neutral} appearance={:outlined}>Cancel</.button>
<.button phx-click="delete" variant={:neutral} appearance={:plain}>Delete</.button>
<.button loading={@saving}>Save</.button>

<%!-- Complex loading states --%>
<.button phx-click="export" loading={@exporting}>
  <:loading_content>
    <.spinner size={:small} /> Exporting {@current_count}/{@total_count}
  </:loading_content>
  Export All
</.button>
```

**Variants:** `:neutral`, `:brand`, `:success`, `:warning`, `:danger`
**Appearances:** `:accent`, `:filled-outlined`, `:filled`, `:outlined`, `:plain`
**Sizes:** `:small`, `:medium` (default), `:large`

**Common Combinations:**
- Primary action: `variant={:brand} appearance={:filled}` - Bold brand-colored button (most prominent)
- Secondary action: `variant={:neutral} appearance={:outlined}` - Neutral with border (medium emphasis)
- Minimal/cancel: `variant={:neutral} appearance={:plain}` - Text-only (low emphasis)
- Success action: `variant={:success} appearance={:filled}` - Green filled button
- Danger action: `variant={:danger} appearance={:filled}` - Red filled button

#### `<.badge>`

Status indicators and tags.

```heex
<.badge variant={:success}>Active</.badge>
<.badge variant={:warning} pill>Pending</.badge>
```

**Variants:** `:primary`, `:success`, `:neutral`, `:warning`, `:danger`

#### `<.card>`

Content containers with optional header, footer, and actions.

```heex
<.card title="Title">
  Content here
</.card>

<.card level={2} title="Section Title" subtitle="Description">
  Main content
  <:actions>
    <.button>Action</.button>
  </:actions>
</.card>
```

#### `<.alert>`

Status messages with default icons.

```heex
<.alert variant={:success}>Operation completed!</.alert>
<.alert variant={:danger}>Error occurred.</.alert>

<%!-- Custom icon --%>
<.alert variant={:brand}>
  <:icon><.icon name="lightbulb" /></:icon>
  Pro tip: Use keyboard shortcuts!
</.alert>
```

**Variants:** `:neutral`, `:brand`, `:success`, `:warning`, `:danger`
**Appearances:** `:accent`, `:filled-outlined`, `:filled`, `:outlined`, `:plain`
**Sizes:** `:small`, `:medium` (default), `:large`

#### `<.modal>`

Dialog overlays for focused interactions.

```heex
<.modal open={@show_modal} title="Confirm Action">
  Are you sure you want to proceed?

  <:actions>
    <.button phx-click="confirm" variant={:primary}>Confirm</.button>
    <.button phx-click="cancel" variant={:ghost}>Cancel</.button>
  </:actions>
</.modal>
```

#### `<.page_header>`

Page title section with optional subtitle and actions.

```heex
<.page_header title="Note Title" subtitle="Type: markdown · Version: 3">
  <:actions>
    <.button phx-click="edit">Edit</.button>
  </:actions>
</.page_header>
```

#### `<.button_group>`

Container for related action buttons.

```heex
<.button_group gap={:m}>
  <.button phx-click="save">Save</.button>
  <.button phx-click="cancel">Cancel</.button>
</.button_group>
```

#### `<.tag_list>`

Display a list of tags/badges.

```heex
<.tag_list tags={@note.tags} variant={:primary} />
```

#### `<.code_block>`

Display formatted code or preformatted text.

```heex
<.code_block content={@note.text} />
<.code_block content={Jason.encode!(@data, pretty: true)} language="json" />
```

#### `<.spinner>`

Loading indicator.

```heex
<.spinner size={:sm} />
<.spinner size={:lg} />
```

#### `<.divider>`

Visual separator.

```heex
<.divider />
<.divider vertical />
```

## Common Patterns

### Page Structure

```heex
<.container>
  <.stack gap={:xl}>
    <.page_header title="Page Title" subtitle="Description">
      <:actions>
        <.button phx-click="action">Action</.button>
      </:actions>
    </.page_header>

    <.card title="Section">
      Content here
    </.card>
  </.stack>
</.container>
```

### Form Actions

```heex
<.button_group>
  <.button phx-click="save" variant={:primary}>Save</.button>
  <.button phx-click="cancel" variant={:ghost}>Cancel</.button>
</.button_group>
```

### Loading States

```heex
<.button phx-click="export" loading={@exporting} loading_text="Exporting...">
  Export
</.button>
```

### Cards with Actions

```heex
<.card level={2} title="Settings">
  Configure your preferences

  <:actions>
    <.button phx-click="save">Save</.button>
  </:actions>
</.card>
```

## Important Guidelines

### ✅ DO

- **Use components for all UI patterns** instead of writing raw HTML/classes
- **Let components handle styling** - avoid adding excessive custom classes
- **Use semantic heading levels** - maintain proper hierarchy (h1 → h2 → h3)
- **Let test IDs generate automatically** from `phx-click` events
- **Compose components together** - they're designed to work in combination
- **Pass level down the hierarchy** for proper heading structure

### ❌ DON'T

- **Don't add Tailwind classes directly** to content (use components instead)
- **Don't skip heading levels** (e.g., h1 → h3)
- **Don't override component styles excessively** - work with the design system
- **Don't mix old and new patterns** in the same file
- **Don't manually create test IDs** for phx-events (they auto-generate)
- **Don't create ad-hoc components in LiveViews** - add them to the component library

## CSS Framework Strategy

Xeno uses a **hybrid framework approach**:

### WebAwesome (Preferred)

Use WebAwesome components (via our component library) for:
- Layout primitives (container, stack, grid, split, flank)
- Content components (cards, buttons, badges, alerts, modals)
- Icons (Font Awesome via `<.icon>`)

**Always prefer the internal UI Library components over directly using WebAwesome or writing custom HTML/CSS.**

### DaisyUI (Legacy - Forms Only)

DaisyUI is still used for form components because:
- Phoenix core components (`<.input>`, `<.form>`) work excellently with DaisyUI
- Form components are stable and don't need refactoring
- The existing implementation is solid

**Form components:** `<.input>`, `<.form>`, textareas, selects, checkboxes, radios

### When to Use What

| Need | Use |
|------|-----|
| Page layout | `<.container>`, `<.stack>`, `<.grid>` |
| Button | `<.button>` from UI library |
| Card/section | `<.card>` from UI library |
| Form input | `<.input>` from core_components (DaisyUI-styled) |
| Icon | `<.icon>` from UI library (Font Awesome) |
| Alert/message | `<.alert>` from UI library |

## Adding New Components

When you need a new UI pattern:

1. **Check if it can be composed** from existing components first
2. **Add it to the component library** (`lib/xeno_web/components/ui.ex` or `layout.ex`)
3. **Write tests** in `test/xeno_web/components/ui_test.exs`
4. **Document it** with examples in the `@doc` attribute
5. **Update this documentation** if it's a commonly-used pattern

**Never create ad-hoc components directly in LiveViews or page templates.** This leads to duplication and inconsistency. Always add reusable patterns to the shared component library.

### Example: Adding a New Component

```elixir
# In lib/xeno_web/components/ui.ex

@doc """
Your component description with examples.

## Examples

    <.your_component attr={value}>
      Content
    </.your_component>
"""
attr :your_attr, :string, required: true
slot :inner_block, required: true

def your_component(assigns) do
  ~H"""
  <div class="your-classes">
    {render_slot(@inner_block)}
  </div>
  """
end
```

Then write comprehensive tests in `test/xeno_web/components/ui_test.exs`.

## Testing with Components

Components make testing easier with stable, semantic structure:

```elixir
test "renders button with auto-generated ID", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/page")

  # Button with phx-click="save_data" automatically has id="save-data-btn"
  assert has_element?(view, "wa-button#save-data-btn")
end

test "card structure", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/page")

  assert has_element?(view, "wa-card")
  assert has_element?(view, "h2", "Section Title")
end
```

## Further Reading

- **[Component Library Plan](../planning/component_library.md)** - Complete implementation details, architecture decisions, and refactoring roadmap
- **WebAwesome Documentation** - <https://webawesome.com/docs>
- **Font Awesome Icons** - <https://fontawesome.com/icons>

## Migration from Old Patterns

If you encounter old code using manual HTML/Tailwind classes:

1. Replace container divs with `<.container>`
2. Replace spacing divs with `<.stack>` or appropriate layout component
3. Replace all `<h1-6>` with `<.heading level={...}>`
4. Replace card structures with `<.card>`
5. Replace button markup with `<.button>`
6. Replace inline SVGs with `<.icon>`
7. Verify heading hierarchy is semantic (no level skips)
8. Run tests and verify they pass

The component library is production-ready with **100% test coverage** and **518 passing tests**. All major templates in Xeno have been refactored to use these components.
