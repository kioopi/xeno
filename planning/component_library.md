# Component Library Refactoring Plan

## Project Status

**Current Phase**: Phase 2 - Basic UI Components (Ready to Start)
**Overall Progress**: 1/9 phases complete (11%)
**Last Updated**: 2025-11-26

### Completed Milestones
- ✅ Phase 1: Foundation & Layout Components (5 components, 19 tests, 100% coverage)

### Available Components
- **Layout**: `<.container>`, `<.stack>`, `<.grid>`, `<.split>`, `<.flank>`
- **UI**: Coming in Phase 2

---

## Executive Summary

This document outlines the comprehensive plan to refactor the Xeno frontend by creating a declarative UI component library based on Phoenix Components and the WebAwesome design system. The goal is to eliminate code duplication, improve maintainability, and create a consistent, semantic approach to building user interfaces.

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [Architecture Decisions](#architecture-decisions)
4. [Component Catalog](#component-catalog)
5. [Implementation Roadmap](#implementation-roadmap)
6. [TDD Plan](#tdd-plan)
7. [Testing Strategy](#testing-strategy)
8. [Migration Guidelines](#migration-guidelines)
9. [Future Considerations](#future-considerations)

---

## Problem Statement

### Current State Analysis

Our current HEEx templates suffer from several maintainability issues:

1. **Code Duplication**: Similar UI patterns are recreated across multiple files with repeated class combinations
2. **Inconsistency**: Same UI elements styled differently in different views
3. **Poor Readability**: Templates describe *how* things look rather than *what* they are
4. **High Maintenance Cost**: Design changes require finding and updating numerous instances
5. **Framework Lock-in**: Direct coupling to Tailwind/DaisyUI classes makes future migrations difficult

### Examples of Current Problems

**Repeated Container Pattern** (appears in 4+ files):
```heex
<div class="max-w-7xl mx-auto px-4 py-8">
  <!-- content -->
</div>
```

**Repeated Card Pattern** (appears in 10+ places):
```heex
<div class="card bg-base-200 mb-6">
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <!-- content -->
  </div>
</div>
```

**Repeated Button Pattern** with loading states:
```heex
<button
  id="export-all-btn"
  phx-click="export_all"
  disabled={@sync_status != :idle}
  class={[
    "btn btn-primary transition-all duration-200",
    @sync_status != :idle && "btn-disabled"
  ]}
>
  <%= cond do %>
    <% @sync_status == :exporting -> %>
      <span class="loading loading-spinner loading-sm"></span>
      Exporting...
    <% true -> %>
      Export All Notes
  <% end %>
</button>
```

**Inline SVG Icons** (50+ instances):
```heex
<svg
  xmlns="http://www.w3.org/2000/svg"
  class="stroke-current shrink-0 h-6 w-6"
  fill="none"
  viewBox="0 0 24 24"
>
  <path
    stroke-linecap="round"
    stroke-linejoin="round"
    stroke-width="2"
    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
  />
</svg>
```

### Impact of Current Approach

- **Development Speed**: Slower feature development due to copy-paste and manual styling
- **Bug Risk**: Inconsistencies lead to subtle UI bugs and confusion
- **Designer Friction**: Design changes require developer time to propagate
- **Cognitive Load**: Developers must remember class combinations and patterns
- **Testing Difficulty**: Inconsistent DOM structure makes test selectors fragile

---

## Solution Overview

### Core Principles

1. **Declarative Components**: Templates should describe *what* things are, not *how* they look
2. **Single Source of Truth**: Each UI pattern defined once, used everywhere
3. **Progressive Enhancement**: Build from simple wrappers to complex compositions
4. **Framework Abstraction**: Decouple views from specific CSS framework implementation
5. **Test-Friendly**: Auto-generate stable test IDs for reliable integration tests

### Vision: Before & After

**Before (Low-level, Imperative)**:
```heex
<div class="max-w-7xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-8">Editor Integration</h1>

  <div class="card bg-base-200 mb-6">
    <div class="card-body">
      <h2 class="card-title">Local Folder Connection</h2>
      <p class="text-sm opacity-70 mb-4">
        Connect a local folder to sync your notes...
      </p>

      <div class="flex gap-4">
        <button
          id="export-all-btn"
          phx-click="export_all"
          class="btn btn-primary"
        >
          Export All Notes
        </button>
      </div>
    </div>
  </div>
</div>
```

**After (High-level, Declarative)**:
```heex
<.container>
  <.stack gap={:xl}>
    <.heading level={1}>Editor Integration</.heading>

    <.card level={2} title="Local Folder Connection">
      <:subtitle>
        Connect a local folder to sync your notes...
      </:subtitle>

      <:actions>
        <.button phx-click="export_all" variant={:primary}>
          Export All Notes
        </.button>
      </:actions>
    </.card>
  </.stack>
</.container>
```

### Benefits

- **80% Less Code**: Eliminate repeated class combinations and structural patterns
- **Better Semantics**: Code reads like a document outline
- **Centralized Styling**: Change button appearance in one place
- **Type Safety**: Component attributes validated at compile time
- **Auto Test IDs**: `phx-click="export_all"` automatically generates `id="export-all-btn"`
- **Hierarchical Headings**: `level` prop ensures semantic heading structure
- **Future-Proof**: Can swap WebAwesome for another system by updating components only

---

## Architecture Decisions

These decisions guide the implementation and should be documented for future reference.

### 1. Hybrid Framework Approach

**Decision**: Keep DaisyUI for forms, use WebAwesome for content components

**Rationale**:
- Phoenix core components (`<.input>`, `<.form>`) work excellently with DaisyUI
- Form components are stable and don't need refactoring
- WebAwesome provides better primitives for content/layout components
- Pragmatic approach: don't fix what isn't broken
- Allows gradual migration as we gain WebAwesome experience

**Boundaries**:
- **DaisyUI Zone**: Forms, inputs, textareas, selects, checkboxes, radios
- **WebAwesome Zone**: Cards, buttons, badges, alerts, modals, layout utilities
- **Shared**: Icons (transitioning to Font Awesome via WebAwesome)

**Future Review**: After 2-3 months of WebAwesome usage, reassess form component strategy

### 2. Icon System Strategy

**Decision**: Pragmatic transition from Heroicons to Font Awesome via WebAwesome

**Approach**:
1. Create `<.icon>` component wrapping `<wa-icon>`
2. Replace inline SVGs with `<.icon>` component (highest priority - 50+ instances)
3. Keep existing Heroicons in core_components.ex for now
4. Long-term goal: Standardize on Font Awesome everywhere

**Migration Path**:
```heex
<!-- Phase 1: Replace inline SVGs -->
<svg xmlns="..." class="...">...</svg>
↓
<.icon name="check-circle" />

<!-- Phase 2: Later, replace Heroicons in core components -->
<.icon name="hero-x-mark" class="..." />
↓
<.icon name="xmark" />
```

**Icon Naming**: Follow Font Awesome conventions (e.g., `check-circle`, `xmark`, `gear`)

### 3. Test ID Generation

**Decision**: Auto-generate test IDs from phx-* event attributes when no explicit `id` exists

**Rules**:
1. If element has explicit `id` attribute → use it (no override)
2. If element has `phx-click` (or other phx-* event) but no `id` → generate from event
3. Generation pattern: `{event_name}-{element_type}` (e.g., `export-all-btn`)
4. Underscores converted to hyphens for DOM ID compatibility

**Implementation**:
```elixir
defp generate_test_id(event_name, element_type \\ "btn") do
  event_name
  |> String.replace("_", "-")
  |> Kernel.<>("-#{element_type}")
end

# In component:
assigns =
  if assigns[:phx_click] && !assigns[:id] do
    assign(assigns, :id, generate_test_id(assigns.phx_click))
  else
    assigns
  end
```

**Benefits**:
- Stable test selectors without manual ID management
- Convention-based approach reduces cognitive load
- Easy to locate elements: "export_all event? Look for #export-all-btn"

### 4. Component Slot Structure

**Decision**: Choose slot complexity based on content type (per-component basis)

**Guidelines**:

| Content Type | Use | Example |
|-------------|-----|---------|
| Simple text | Attribute | `title="My Title"` |
| Simple optional text | Attribute with default nil | `subtitle="Optional text"` |
| Rich content (HTML) | Named slot | `<:header>...</:header>` |
| Primary content | Inner block (default slot) | `<.card>content</.card>` |
| Multiple optional sections | Multiple named slots | `<:actions>`, `<:footer>` |

**Examples**:

```heex
<!-- Simple: text attributes -->
<.badge variant={:success}>Active</.badge>

<!-- Medium: mix of attributes and default slot -->
<.card title="Title" subtitle="Optional">
  Main content here
</.card>

<!-- Complex: named slots for structure -->
<.panel level={1}>
  <:header>
    <.heading level={1}>Title</.heading>
    <.button>Action</.button>
  </:header>

  <:content>
    Main content
  </:content>

  <:actions>
    <.button>Save</.button>
    <.button>Cancel</.button>
  </:actions>
</.panel>
```

**Principle**: Start simple, add slots only when needed for flexibility

### 5. Hierarchical Heading Levels

**Decision**: Use `level` prop to maintain semantic heading hierarchy

**Concept**: Components that contain headings should accept a `level` prop indicating their position in the document hierarchy, and pass `level + 1` to nested components.

**Why This Matters**:
- Semantic HTML requires proper heading hierarchy (`h1` → `h2` → `h3`, no skips)
- Accessibility tools use heading structure for navigation
- Manual heading management is error-prone

**Implementation Pattern**:

```heex
<!-- Page level: starts at level 1 -->
<.panel level={1} title="Main Section">
  <!-- Panel renders its title as h1 -->

  <.card level={2} title="Subsection">
    <!-- Card renders its title as h2 -->

    <!-- Nested components get level 3 -->
    <.heading level={3}>Details</.heading>
  </.card>
</.panel>
```

**Component Implementation**:
```elixir
attr :level, :integer, required: true
attr :title, :string, required: true

def panel(assigns) do
  ~H"""
  <section>
    <.heading level={@level}>{@title}</.heading>
    <!-- Pass level + 1 to children if needed -->
    <%= render_slot(@inner_block, level: @level + 1) %>
  </section>
  """
end
```

**Benefits**:
- Correct heading hierarchy maintained automatically
- Component composition respects document structure
- Screen readers navigate properly

---

## Component Catalog

### Component Organization

```
lib/xeno_web/components/
├── core_components.ex     # Keep as-is (forms, DaisyUI)
├── layout.ex              # NEW - Layout utilities
├── ui.ex                  # NEW - UI components
└── navigation.ex          # Existing (keep)
```

### Layout Components (`layout.ex`)

These wrap WebAwesome CSS utility classes to provide semantic layout primitives.

#### `<.container>`

**Purpose**: Page-level content wrapper with responsive max-width

**API**:
```elixir
attr :max_width, :atom, default: :xl, values: [:sm, :md, :lg, :xl, :full]
attr :class, :string, default: nil
slot :inner_block, required: true
```

**Usage**:
```heex
<.container max_width={:lg}>
  Page content here
</.container>
```

**Renders**: `<div class="max-w-{size} mx-auto px-4 py-8">`

**WebAwesome Mapping**: Custom (not a WA component)

---

#### `<.stack>`

**Purpose**: Vertical layout with consistent spacing between children

**API**:
```elixir
attr :gap, :atom, default: :m, values: [:s, :m, :l, :xl]
attr :class, :string, default: nil
slot :inner_block, required: true
```

**Usage**:
```heex
<.stack gap={:l}>
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
</.stack>
```

**Renders**: `<div class="wa-stack wa-gap-{size}">`

**WebAwesome Mapping**: `wa-stack` utility class

---

#### `<.grid>`

**Purpose**: Responsive auto-grid layout

**API**:
```elixir
attr :min_column_size, :string, default: "20ch"
attr :gap, :atom, default: :m, values: [:s, :m, :l, :xl]
attr :class, :string, default: nil
slot :inner_block, required: true
```

**Usage**:
```heex
<.grid min_column_size="300px" gap={:l}>
  <.card>Card 1</.card>
  <.card>Card 2</.card>
  <.card>Card 3</.card>
</.grid>
```

**Renders**: `<div class="wa-grid" style="--min-column-size: {size}">`

**WebAwesome Mapping**: `wa-grid` utility class

---

#### `<.split>`

**Purpose**: Distribute items evenly across space (horizontal or vertical)

**API**:
```elixir
attr :direction, :atom, default: :horizontal, values: [:horizontal, :vertical]
attr :gap, :atom, default: :m, values: [:s, :m, :l, :xl]
attr :class, :string, default: nil
slot :inner_block, required: true
```

**Usage**:
```heex
<.split gap={:m}>
  <div>Left content</div>
  <div>Right content</div>
</.split>
```

**Renders**: `<div class="wa-split wa-gap-{size}">`

**WebAwesome Mapping**: `wa-split` utility class

---

#### `<.flank>`

**Purpose**: Icon/avatar + text layout (one item flanks another that fills space)

**API**:
```elixir
attr :gap, :atom, default: :m, values: [:s, :m, :l]
attr :class, :string, default: nil
slot :inner_block, required: true
```

**Usage**:
```heex
<.flank gap={:s}>
  <.icon name="check-circle" />
  <span>Operation successful</span>
</.flank>
```

**Renders**: `<div class="wa-flank wa-gap-{size}">`

**WebAwesome Mapping**: `wa-flank` utility class

---

### UI Components (`ui.ex`)

These wrap WebAwesome web components and provide higher-level UI primitives.

#### `<.heading>`

**Purpose**: Semantic headings with consistent styling and hierarchy support

**API**:
```elixir
attr :level, :integer, required: true, values: [1, 2, 3, 4, 5, 6]
attr :class, :string, default: nil
attr :rest, :global
slot :inner_block, required: true
```

**Usage**:
```heex
<.heading level={1}>Main Title</.heading>
<.heading level={2}>Subsection</.heading>
```

**Renders**: `<h{level} class="...">` with appropriate sizing classes

**Default Styles**:
- `h1`: `text-3xl font-bold`
- `h2`: `text-2xl font-semibold`
- `h3`: `text-xl font-semibold`
- `h4`: `text-lg font-semibold`
- `h5`: `text-base font-semibold`
- `h6`: `text-sm font-semibold`

---

#### `<.icon>`

**Purpose**: Render icons using WebAwesome (Font Awesome)

**API**:
```elixir
attr :name, :string, required: true
attr :variant, :atom, default: :regular, values: [:solid, :regular, :light, :thin, :duotone, :brands]
attr :size, :string, default: nil  # e.g., "2rem", "24px"
attr :class, :string, default: nil
attr :rest, :global
```

**Usage**:
```heex
<.icon name="check-circle" variant={:solid} />
<.icon name="gear" size="1.5rem" />
<.icon name="github" variant={:brands} />
```

**Renders**: `<wa-icon name="{name}" variant="{variant}"></wa-icon>`

**WebAwesome Mapping**: `<wa-icon>` component

**Icon Names**: Use Font Awesome 6 icon names (without `fa-` prefix)

---

#### `<.button>`

**Purpose**: Action button with variants, loading states, and auto test IDs

**API**:
```elixir
attr :id, :string, default: nil
attr :variant, :atom, default: :primary, values: [:primary, :secondary, :ghost, :soft]
attr :size, :atom, default: :md, values: [:sm, :md, :lg]
attr :loading, :boolean, default: false
attr :disabled, :boolean, default: false
attr :phx_click, :string, default: nil
attr :class, :string, default: nil
attr :rest, :global, include: ~w(phx-click phx-value-* disabled)
slot :inner_block, required: true
```

**Usage**:
```heex
<!-- Auto-generates id="export-all-btn" -->
<.button phx-click="export_all" variant={:primary}>
  Export All
</.button>

<!-- With loading state -->
<.button phx-click="save" loading={@saving}>
  Save Changes
</.button>

<!-- Explicit ID (no auto-generation) -->
<.button id="custom-id" phx-click="action">
  Action
</.button>
```

**Renders**: `<wa-button variant="{variant}" size="{size}">` with loading spinner if needed

**WebAwesome Mapping**: `<wa-button>` component

**Auto Test ID**: If `phx-click` exists and no `id` provided → `id="{event}-btn"`

---

#### `<.badge>`

**Purpose**: Status indicator, tag, or label

**API**:
```elixir
attr :variant, :atom, default: :primary, values: [:primary, :success, :neutral, :warning, :danger]
attr :pill, :boolean, default: false
attr :removable, :boolean, default: false
attr :class, :string, default: nil
attr :rest, :global
slot :inner_block, required: true
```

**Usage**:
```heex
<.badge variant={:success}>Active</.badge>
<.badge variant={:warning} pill>Pending</.badge>
<.badge variant={:primary} removable>Tag</.badge>
```

**Renders**: `<wa-tag variant="{variant}" pill={bool} removable={bool}>`

**WebAwesome Mapping**: `<wa-tag>` component

---

#### `<.spinner>`

**Purpose**: Loading indicator

**API**:
```elixir
attr :size, :atom, default: :md, values: [:sm, :md, :lg]
attr :class, :string, default: nil
```

**Usage**:
```heex
<.spinner size={:sm} />
<.spinner size={:lg} />
```

**Renders**: `<wa-spinner style="font-size: {size}"></wa-spinner>`

**WebAwesome Mapping**: `<wa-spinner>` component

---

#### `<.divider>`

**Purpose**: Visual separator between sections

**API**:
```elixir
attr :vertical, :boolean, default: false
attr :class, :string, default: nil
```

**Usage**:
```heex
<.divider />
<.divider vertical />
```

**Renders**: `<wa-divider vertical={bool}></wa-divider>`

**WebAwesome Mapping**: `<wa-divider>` component

---

#### `<.card>`

**Purpose**: Content container with optional header, footer

**API**:
```elixir
attr :level, :integer, default: nil
attr :title, :string, default: nil
attr :subtitle, :string, default: nil
attr :class, :string, default: nil
attr :rest, :global
slot :header, doc: "Custom header content (overrides title/subtitle)"
slot :inner_block, required: true
slot :footer, doc: "Footer content"
slot :actions, doc: "Action buttons"
```

**Usage**:
```heex
<!-- Simple -->
<.card title="Title">
  Content here
</.card>

<!-- With level (renders title as heading) -->
<.card level={2} title="Section Title" subtitle="Description">
  Content here
</.card>

<!-- Complex with slots -->
<.card>
  <:header>
    <.heading level={2}>Custom Header</.heading>
  </:header>

  Main content

  <:actions>
    <.button>Action</.button>
  </:actions>

  <:footer>
    Footer text
  </:footer>
</.card>
```

**Renders**: `<wa-card>` with slots mapped to WebAwesome structure

**WebAwesome Mapping**: `<wa-card>` component

---

#### `<.alert>`

**Purpose**: Status message or callout

**API**:
```elixir
attr :variant, :atom, default: :info, values: [:info, :success, :warning, :danger, :brand]
attr :closable, :boolean, default: false
attr :class, :string, default: nil
attr :rest, :global
slot :icon, doc: "Custom icon (defaults to variant icon)"
slot :inner_block, required: true
```

**Usage**:
```heex
<.alert variant={:success}>
  Operation completed successfully!
</.alert>

<.alert variant={:danger} closable>
  <:icon><.icon name="exclamation-triangle" /></:icon>
  An error occurred.
</.alert>
```

**Renders**: `<wa-callout variant="{variant}" closable={bool}>`

**WebAwesome Mapping**: `<wa-callout>` component

---

#### `<.modal>`

**Purpose**: Dialog overlay for focused interactions

**API**:
```elixir
attr :open, :boolean, default: false
attr :title, :string, required: true
attr :size, :atom, default: :md, values: [:sm, :md, :lg, :xl]
attr :class, :string, default: nil
attr :rest, :global, include: ~w(phx-click)
slot :inner_block, required: true
slot :actions, doc: "Action buttons in footer"
```

**Usage**:
```heex
<.modal open={@show_modal} title="Confirm Action">
  Are you sure you want to proceed?

  <:actions>
    <.button phx-click="confirm" variant={:primary}>
      Confirm
    </.button>
    <.button phx-click="cancel" variant={:ghost}>
      Cancel
    </.button>
  </:actions>
</.modal>
```

**Renders**: Custom modal structure using WebAwesome components

**WebAwesome Mapping**: Composed from multiple WA components

---

#### `<.page_header>`

**Purpose**: Page title section with optional actions

**API**:
```elixir
attr :level, :integer, default: 1
attr :title, :string, required: true
attr :subtitle, :string, default: nil
attr :class, :string, default: nil
slot :actions, doc: "Action buttons"
```

**Usage**:
```heex
<.page_header title="Note Title" subtitle="Type: markdown · Version: 3">
  <:actions>
    <.button phx-click="edit" variant={:primary}>
      Edit
    </.button>
  </:actions>
</.page_header>
```

**Renders**: Custom structure with heading and action layout

---

#### `<.button_group>`

**Purpose**: Container for related action buttons

**API**:
```elixir
attr :gap, :atom, default: :m, values: [:s, :m, :l]
attr :class, :string, default: nil
slot :inner_block, required: true
```

**Usage**:
```heex
<.button_group gap={:s}>
  <.button phx-click="save">Save</.button>
  <.button phx-click="cancel">Cancel</.button>
</.button_group>
```

**Renders**: `<div class="flex gap-{size}">`

---

#### `<.tag_list>`

**Purpose**: Render a list of tags/badges

**API**:
```elixir
attr :tags, :list, required: true
attr :variant, :atom, default: :primary
attr :class, :string, default: nil
```

**Usage**:
```heex
<.tag_list tags={@note.tags} variant={:primary} />
```

**Renders**: Flex container with `<.badge>` for each tag

---

#### `<.code_block>`

**Purpose**: Display formatted code or preformatted text

**API**:
```elixir
attr :content, :string, required: true
attr :language, :string, default: nil
attr :class, :string, default: nil
```

**Usage**:
```heex
<.code_block content={@note.text} />
<.code_block content={Jason.encode!(@data, pretty: true)} language="json" />
```

**Renders**: `<wa-card>` containing `<pre><code>`

---

## Implementation Roadmap

### Overview

The implementation follows a Test-Driven Development (TDD) approach with incremental refactoring. Each phase builds on the previous one and maintains backward compatibility.

**Total Estimated Time**: 15-20 hours
**Approach**: Red-Green-Refactor cycle
**Testing**: Component unit tests + integration tests after each refactor

### Current Status

- ✅ **Phase 1**: Foundation & Layout Components - **COMPLETE**
- 🔄 **Phase 2**: Basic UI Components - **READY TO START**
- ⏸️ **Phase 3**: Refactor `info_live.html.heex` - Pending
- ⏸️ **Phase 4**: Advanced UI Components - Pending
- ⏸️ **Phase 5**: Refactor `note_show_live.html.heex` - Pending
- ⏸️ **Phase 6**: Refactor `note_edit_live.html.heex` - Pending
- ⏸️ **Phase 7**: Complex Components & Modal - Pending
- ⏸️ **Phase 8**: Refactor `sync_live.html.heex` - Pending
- ⏸️ **Phase 9**: Testing, Documentation & Polish - Pending

**Progress**: 1/9 phases complete (11%)

---

### Phase 1: Foundation & Layout Components ✅ COMPLETE

**Duration**: 2-3 hours (Completed in ~2 hours)

**Goal**: Establish component infrastructure and implement layout primitives

**Status**: ✅ **COMPLETE** - All success criteria met

**Completed Tasks**:

1. ✅ **Setup** (30 min)
   - Created `lib/xeno_web/components/layout.ex` (161 lines)
   - Created `lib/xeno_web/components/ui.ex` (empty skeleton)
   - Updated `lib/xeno_web.ex` html_helpers to import new modules
   - Created test files structure

2. ✅ **Document Architecture Decisions** (30 min)
   - Created this document (`planning/component_library.md`)
   - Documented framework strategy, icon approach, etc.

3. ✅ **Implement Layout Components** (1-2 hours)
   - Wrote tests for `<.container>` (TDD) - 4 tests
   - Implemented `<.container>` with full documentation
   - Wrote tests for `<.stack>` (TDD) - 4 tests
   - Implemented `<.stack>` wrapping `wa-stack`
   - Wrote tests for `<.grid>` (TDD) - 4 tests
   - Implemented `<.grid>` wrapping `wa-grid`
   - Wrote tests for `<.split>` (TDD) - 4 tests
   - Implemented `<.split>` wrapping `wa-split`
   - Wrote tests for `<.flank>` (TDD) - 3 tests
   - Implemented `<.flank>` wrapping `wa-flank`

**Success Criteria** (All Met):
- ✅ All layout component tests pass (19/19 tests passing)
- ✅ Can use `<.stack gap={:l}>` in any template (imports working)
- ✅ Test coverage: 100% for layout.ex

**Deliverables**:
- ✅ `lib/xeno_web/components/layout.ex` (161 lines, 5 components)
- ✅ `lib/xeno_web/components/ui.ex` (empty skeleton for Phase 2)
- ✅ `test/xeno_web/components/layout_test.exs` (238 lines, 19 comprehensive tests)
- ✅ Updated `lib/xeno_web.ex` (added imports)
- ✅ This documentation file (updated)

**Test Results**:
```
mix test test/xeno_web/components/layout_test.exs
...................
Finished in 0.2 seconds (0.2s async, 0.00s sync)
19 tests, 0 failures

Coverage:
100.00% | XenoWeb.Components.Layout

Full Suite:
359 tests, 0 failures, 2 skipped
```

---

### Phase 2: Basic UI Components

**Duration**: 2-3 hours

**Goal**: Implement foundational UI primitives

**Tasks**:

1. **`<.heading>` Component** (20 min)
   - Write tests: renders correct tag, applies level-based classes, accepts custom class
   - Implement with level-based styling
   - Test hierarchical behavior

2. **`<.icon>` Component** (30 min)
   - Write tests: wraps wa-icon, passes attributes, supports variants
   - Implement wrapping `<wa-icon>`
   - Document Font Awesome icon names

3. **`<.button>` Component** (1 hour)
   - Write tests: renders variants, auto-generates test IDs, respects explicit IDs
   - Implement with auto test-id generation
   - Write tests: loading state, disabled state
   - Implement loading state with spinner
   - Test phx-* attribute pass-through

4. **`<.badge>` Component** (20 min)
   - Write tests: renders variants, pill style, removable
   - Implement wrapping `<wa-tag>`

5. **`<.spinner>` Component** (10 min)
   - Write tests: renders with size
   - Implement wrapping `<wa-spinner>`

6. **`<.divider>` Component** (10 min)
   - Write tests: horizontal/vertical
   - Implement wrapping `<wa-divider>`

**Success Criteria**:
- All UI component tests pass
- Auto test-id generation works correctly
- Can use components in templates
- Test coverage: 100% for new components

**Deliverables**:
- Updated `lib/xeno_web/components/ui.ex` (6 components)
- Updated `test/xeno_web/components/ui_test.exs` (comprehensive tests)

---

### Phase 3: Refactor `info_live.html.heex`

**Duration**: 1 hour

**Goal**: Prove the concept with simplest template, establish refactoring pattern

**Tasks**:

1. **Write Integration Tests** (20 min)
   - Test current info_live renders correctly
   - Test key content is present
   - Take baseline screenshots (optional)

2. **Refactor Template** (30 min)
   - Replace container divs with `<.container>`
   - Replace headings with `<.heading level={...}>`
   - Use `<.stack>` for vertical spacing
   - Use `<.grid>` for two-column layout
   - Document `<.card>` needs (Phase 4)

3. **Verify** (10 min)
   - All tests pass
   - Visual inspection: matches original
   - No console errors
   - Run full test suite

**Success Criteria**:
- Template is 30-50% smaller
- More readable and semantic
- Identical visual output
- All integration tests pass

**Deliverables**:
- Refactored `lib/xeno_web/live/info_live.html.heex`
- Integration tests pass

---

### Phase 4: Advanced UI Components

**Duration**: 2-3 hours

**Goal**: Implement complex UI components

**Tasks**:

1. **`<.card>` Component** (45 min)
   - Write tests: renders with title, subtitle, slots
   - Implement wrapping `<wa-card>`
   - Test level prop integration
   - Test header/footer/actions slots

2. **`<.alert>` Component** (30 min)
   - Write tests: renders variants, closable, custom icon
   - Implement wrapping `<wa-callout>`
   - Test icon slot

3. **`<.page_header>` Component** (20 min)
   - Write tests: renders title/subtitle, actions slot
   - Implement with flexible layout

4. **`<.button_group>` Component** (15 min)
   - Write tests: renders children with gap
   - Implement simple flex container

5. **`<.tag_list>` Component** (20 min)
   - Write tests: renders list of badges
   - Implement iterating over tags

6. **`<.code_block>` Component** (20 min)
   - Write tests: renders formatted code
   - Implement with pre/code structure

**Success Criteria**:
- All component tests pass
- Components work in isolation and composition
- Test coverage: 100%

**Deliverables**:
- Updated `lib/xeno_web/components/ui.ex` (6 more components)
- Updated `test/xeno_web/components/ui_test.exs`

---

### Phase 5: Refactor `note_show_live.html.heex`

**Duration**: 1-2 hours

**Goal**: Apply component library to medium-complexity template

**Tasks**:

1. **Write Integration Tests** (15 min)
   - Test note display renders correctly
   - Test tags display
   - Test edit button

2. **Refactor Template** (1 hour)
   - Replace header with `<.page_header>`
   - Replace tags with `<.tag_list>`
   - Replace content cards with `<.card>`
   - Use `<.code_block>` for pre-formatted content
   - Use `<.heading>` with proper levels
   - Use `<.stack>` for layout

3. **Verify** (15 min)
   - Visual inspection
   - Integration tests pass
   - Full test suite passes

**Success Criteria**:
- Template is 40-60% smaller
- Semantic heading hierarchy maintained
- All tests pass

**Deliverables**:
- Refactored `lib/xeno_web/live/note_show_live.html.heex`

---

### Phase 6: Refactor `note_edit_live.html.heex`

**Duration**: 1 hour

**Goal**: Apply components to form-heavy template (minimal changes expected)

**Tasks**:

1. **Write Integration Tests** (15 min)
   - Test form renders
   - Test form submission
   - Test validation

2. **Refactor Template** (30 min)
   - Use `<.stack>` for form field spacing
   - Replace button group with `<.button_group>`
   - Use `<.heading>` for title
   - Keep form inputs as-is (DaisyUI strategy)

3. **Verify** (15 min)
   - Form works correctly
   - Validation works
   - All tests pass

**Success Criteria**:
- Template slightly cleaner
- Forms still work perfectly
- All tests pass

**Deliverables**:
- Refactored `lib/xeno_web/live/note_edit_live.html.heex`

---

### Phase 7: Complex Components & Modal

**Duration**: 2-3 hours

**Goal**: Implement remaining complex components

**Tasks**:

1. **`<.modal>` Component** (1.5 hours)
   - Write tests: renders when open, closes, backdrop click
   - Implement modal structure
   - Test title and actions slots
   - Test phx-click integration
   - Test keyboard escape handling

2. **Enhanced `<.button>` for Complex Loading States** (30 min)
   - Write tests: loading text, progress display
   - Enhance button to support conditional content in loading state

3. **Enhanced `<.alert>` with Icons** (30 min)
   - Add default icons for each variant
   - Support custom icon slot

**Success Criteria**:
- Modal works with LiveView events
- Components handle edge cases
- All tests pass

**Deliverables**:
- Updated `lib/xeno_web/components/ui.ex`
- Updated `test/xeno_web/components/ui_test.exs`

---

### Phase 8: Refactor `sync_live.html.heex`

**Duration**: 2-3 hours

**Goal**: Apply full component library to most complex template

**Tasks**:

1. **Write Integration Tests** (30 min)
   - Test directory connection flow
   - Test export/import buttons
   - Test error display
   - Test conflict modal

2. **Refactor Template - Part 1: Structure** (1 hour)
   - Replace container with `<.container>`
   - Use `<.heading>` throughout
   - Use `<.card>` for sections
   - Use `<.stack>` for layout

3. **Refactor Template - Part 2: Components** (1 hour)
   - Replace alerts with `<.alert>`
   - Replace badges with `<.badge>`
   - Replace buttons with `<.button>` (loading states)
   - Replace inline SVGs with `<.icon>`
   - Replace conflict modal with `<.modal>`
   - Use `<.button_group>` for actions

4. **Verify** (30 min)
   - All functionality works
   - Visual inspection
   - Integration tests pass
   - Full test suite passes

**Success Criteria**:
- Template is 50-70% smaller
- Much more readable
- No inline SVGs remain
- All functionality preserved
- All tests pass

**Deliverables**:
- Refactored `lib/xeno_web/live/sync_live.html.heex`

---

### Phase 9: Testing, Documentation & Polish

**Duration**: 2-3 hours

**Goal**: Ensure quality, document usage, review consistency

**Tasks**:

1. **Component Documentation** (1 hour)
   - Add @doc to all components
   - Add usage examples
   - Document all attributes and slots
   - Create examples in this guide

2. **Test Coverage Review** (30 min)
   - Run coverage report
   - Ensure 100% component coverage
   - Add missing edge case tests

3. **Integration Testing** (30 min)
   - Manual testing of all views
   - Test interactions
   - Test responsive behavior
   - Browser compatibility check

4. **Consistency Review** (30 min)
   - Review all refactored templates for consistency
   - Ensure heading hierarchy is correct
   - Verify test IDs are generated correctly
   - Check for any remaining inline styles/classes

5. **Performance Check** (30 min)
   - Measure render times
   - Check for any performance regressions
   - Optimize if needed

**Success Criteria**:
- Test coverage ≥ 95%
- All documentation complete
- No visual regressions
- All templates use consistent patterns

**Deliverables**:
- Updated component documentation
- Test coverage report
- Performance benchmark (if needed)
- This guide finalized

---

## TDD Plan

### Test-Driven Development Approach

We follow strict TDD for all component development:

**Red-Green-Refactor Cycle**:
1. **Red**: Write a failing test that defines desired behavior
2. **Green**: Write minimal code to make the test pass
3. **Refactor**: Clean up code while keeping tests green

### Testing Layers

#### 1. Component Unit Tests

**Location**: `test/xeno_web/components/layout_test.exs`, `ui_test.exs`

**Purpose**: Test individual components in isolation

**Coverage Requirements**:
- Renders correct HTML structure
- Applies correct classes
- Handles all attribute combinations
- Respects slot content
- Passes through `@rest` attributes
- Edge cases (nil values, empty strings, etc.)

**Example Test Structure**:

```elixir
defmodule XenoWeb.Components.LayoutTest do
  use XenoWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "stack/1" do
    test "renders with default gap" do
      html =
        render_component(&XenoWeb.Layout.stack/1, %{},
          inner_block: [
            %{content: "<div>Item 1</div>"},
            %{content: "<div>Item 2</div>"}
          ]
        )

      assert html =~ ~r/class="[^"]*wa-stack/
      assert html =~ ~r/class="[^"]*wa-gap-m/
      assert html =~ "Item 1"
      assert html =~ "Item 2"
    end

    test "renders with custom gap" do
      html =
        render_component(&XenoWeb.Layout.stack/1, %{gap: :l},
          inner_block: [%{content: "<div>Item</div>"}]
        )

      assert html =~ ~r/class="[^"]*wa-gap-l/
    end

    test "passes through custom class" do
      html =
        render_component(&XenoWeb.Layout.stack/1, %{class: "custom"},
          inner_block: [%{content: "<div>Item</div>"}]
        )

      assert html =~ ~r/class="[^"]*custom/
    end
  end
end
```

#### 2. Component Integration Tests

**Purpose**: Test components working together in realistic scenarios

**Example**:

```elixir
describe "card with heading hierarchy" do
  test "renders title at correct level" do
    html =
      render_component(&XenoWeb.UI.card/1, %{level: 2, title: "Card Title"},
        inner_block: [%{content: "Card content"}]
      )

    assert html =~ ~r/<h2[^>]*>Card Title<\/h2>/
  end

  test "nested components receive incremented level" do
    # Test that level prop is passed down correctly
  end
end
```

#### 3. LiveView Integration Tests

**Location**: Existing test files for each LiveView

**Purpose**: Ensure refactored templates maintain functionality

**Approach**:
1. Write tests for current behavior (baseline)
2. Refactor template
3. Verify tests still pass (no behavior change)

**Example**:

```elixir
defmodule XenoWeb.InfoLiveTest do
  use XenoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "displays notes directory", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/info")

    assert has_element?(view, "h1", "Xeno Installation Information")
    # After refactor, still works but uses <.heading> internally
  end
end
```

#### 4. Visual Regression Tests (Optional)

**Tools**: Percy, Chromatic, or manual screenshots

**Purpose**: Ensure visual appearance unchanged after refactor

**Approach**:
1. Take baseline screenshots before refactor
2. Take comparison screenshots after refactor
3. Manually verify visual parity

### Test Checklist per Component

For each new component, verify:

- [ ] Renders correct HTML tag/structure
- [ ] Applies correct WebAwesome classes
- [ ] Handles required attributes
- [ ] Handles optional attributes with defaults
- [ ] Passes through `@rest` attributes correctly
- [ ] Renders slot content correctly
- [ ] Handles multiple slots if applicable
- [ ] Handles edge cases (nil, empty, etc.)
- [ ] Auto-generates test IDs correctly (if applicable)
- [ ] Respects explicit IDs over auto-generation
- [ ] Applies custom classes via `class` attribute
- [ ] Works in composition with other components

### Testing Tools

**Available Tools**:
- `Phoenix.LiveViewTest` - Component rendering
- `Phoenix.ConnCase` - Integration tests
- `Floki` - HTML parsing and assertions (optional)
- `assert html =~ regex` - Pattern matching

**Useful Patterns**:

```elixir
# Render a component
html = render_component(&MyComponent.component/1, assigns, slots)

# Check for element presence
assert html =~ ~r/<button[^>]*id="export-all-btn"/

# Check for class application
assert html =~ ~r/class="[^"]*wa-stack/

# Parse HTML (with Floki)
document = Floki.parse_document!(html)
assert [{"button", attrs, _}] = Floki.find(document, "button")
assert Enum.any?(attrs, fn {k, v} -> k == "id" && v == "export-all-btn" end)
```

---

## Testing Strategy

### Test Organization

```
test/xeno_web/components/
├── layout_test.exs          # Layout component unit tests
├── ui_test.exs              # UI component unit tests
```

### Running Tests

```bash
# Run all tests
mix test

# Run component tests only
mix test test/xeno_web/components/

# Run specific component test file
mix test test/xeno_web/components/layout_test.exs

# Run with coverage
mix test --cover

# Run failed tests only
mix test --failed
```

### Test Coverage Goals

- **Component Unit Tests**: 100% coverage
- **Integration Tests**: Cover all refactored templates
- **Overall Project**: Maintain or improve current coverage

### Continuous Testing

During development:
1. Keep tests running in watch mode: `mix test.watch`
2. Fix failing tests immediately (don't accumulate debt)
3. Refactor only when tests are green
4. Add tests for bugs before fixing

---

## Migration Guidelines

### For Developers: Using the Component Library

#### Quick Start

```heex
<%!-- Old way (manual classes) --%>
<div class="max-w-7xl mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-8">Title</h1>
  <div class="space-y-6">
    <div class="card bg-base-200">
      <div class="card-body">
        Content
      </div>
    </div>
  </div>
</div>

<%!-- New way (components) --%>
<.container>
  <.stack gap={:xl}>
    <.heading level={1}>Title</.heading>
    <.card>
      Content
    </.card>
  </.stack>
</.container>
```

#### Component Selection Guide

**Need vertical spacing?** → Use `<.stack>`

**Need a grid layout?** → Use `<.grid>`

**Need a content card?** → Use `<.card>`

**Need a button?** → Use `<.button>` (auto test-id generation!)

**Need icons?** → Use `<.icon name="...">` (Font Awesome names)

**Need a heading?** → Use `<.heading level={...}>` (semantic hierarchy)

**Need status indicator?** → Use `<.badge variant={...}>`

**Need alert message?** → Use `<.alert variant={...}>`

#### Common Patterns

**Page Structure**:
```heex
<.container>
  <.stack gap={:xl}>
    <.page_header title="Page Title" subtitle="Description">
      <:actions>
        <.button phx-click="action">Action</.button>
      </:actions>
    </.page_header>

    <.card title="Section">
      Content
    </.card>
  </.stack>
</.container>
```

**Form Actions**:
```heex
<.button_group>
  <.button phx-click="save" variant={:primary}>
    Save
  </.button>
  <.button phx-click="cancel" variant={:ghost}>
    Cancel
  </.button>
</.button_group>
```

**Loading State**:
```heex
<.button phx-click="export" loading={@exporting}>
  <%= if @exporting, do: "Exporting...", else: "Export" %>
</.button>
```

**Tag List**:
```heex
<.tag_list tags={@note.tags} variant={:primary} />
```

### Refactoring Checklist

When refactoring a template:

- [ ] Replace container divs with `<.container>`
- [ ] Replace spacing divs with `<.stack>` or appropriate layout component
- [ ] Replace all `<h1-6>` with `<.heading level={...}>`
- [ ] Replace card structures with `<.card>`
- [ ] Replace button markup with `<.button>`
- [ ] Replace inline SVGs with `<.icon>`
- [ ] Replace badge/tag markup with `<.badge>`
- [ ] Replace alert markup with `<.alert>`
- [ ] Verify heading hierarchy is semantic (no level skips)
- [ ] Verify all phx-* events generate test IDs
- [ ] Run tests and verify they pass
- [ ] Visual inspection for parity

### Do's and Don'ts

**DO**:
- Use components for all UI patterns
- Let components handle styling
- Use semantic heading levels
- Let test IDs generate automatically
- Compose components together
- Pass level down the hierarchy

**DON'T**:
- Add Tailwind classes directly to content (use components)
- Skip heading levels (h1 → h3)
- Override component styles excessively
- Mix old and new patterns in same file
- Manually create test IDs for phx-events

---

## Future Considerations

### Short-term (Next 3 Months)

1. **Form Components Evaluation**
   - Monitor WebAwesome form component maturity
   - Consider migrating `<.input>`, `<.textarea>`, etc.
   - Evaluate vs current DaisyUI implementation

2. **Icon Migration Completion**
   - Replace all Heroicons with Font Awesome
   - Update core_components.ex icon references
   - Standardize icon usage across app

3. **Component Library Expansion**
   - Add components as new patterns emerge
   - Document new components following this guide
   - Maintain test coverage

### Mid-term (6-12 Months)

1. **Advanced Components**
   - Dropdown menus
   - Date pickers
   - Rich text editor components
   - Data tables

2. **Theme System**
   - Define design tokens
   - Support light/dark mode
   - Customizable color schemes

3. **Animation Library**
   - Consistent transition patterns
   - Loading states
   - Micro-interactions

### Long-term (12+ Months)

1. **Design System Documentation**
   - Interactive component explorer
   - Usage guidelines
   - Design principles

2. **Component Variants**
   - Multiple visual styles
   - Theming support
   - Brand customization

3. **Performance Optimization**
   - Lazy loading for large component trees
   - Optimized rendering
   - Bundle size optimization

---

## Appendix

### WebAwesome Resources

- **Documentation**: https://webawesome.com/docs
- **Components**: https://webawesome.com/components
- **Utilities**: https://webawesome.com/utilities
- **Font Awesome Icons**: https://fontawesome.com/icons

### Related Planning Documents

- `planning/ui-library.md` - Original UI library plan
- `planning/webawesome-components.md` - WebAwesome component reference
- `deps_docs/webawesome-docs.md` - Full WebAwesome documentation

### Component API Reference

See individual component sections above for detailed API documentation.

### Change Log

- **2025-11-26**: Initial document created with comprehensive plan
- **2025-11-26**: ✅ **Phase 1 Complete** - All 5 layout components implemented with 100% test coverage (19 passing tests)

---

## Summary

This component library refactoring will transform the Xeno frontend from an imperative, class-heavy approach to a declarative, semantic component-based architecture. By wrapping WebAwesome components and creating composable UI primitives, we achieve:

- **80% reduction** in template code
- **100% consistency** across views
- **Zero duplication** of UI patterns
- **Better semantics** and accessibility
- **Future-proof architecture** decoupled from specific frameworks
- **Improved developer experience** with readable, maintainable code

The phased approach ensures we can validate each step, maintain test coverage, and deliver incremental value throughout the implementation.
