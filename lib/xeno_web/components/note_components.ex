defmodule XenoWeb.NoteComponents do
  @moduledoc """
  Reusable components for note creation and editing forms.
  """
  use XenoWeb, :html
  alias XenoWeb.CoreComponents

  @doc """
  Renders a form field wrapper with label, error display, and helper text.

  This component provides consistent styling and structure for form fields.

  ## Attributes

  * `label` - Field label text
  * `required` - Whether field is required (shows indicator)
  * `error` - Error message to display (optional)
  * `error_class` - CSS class for error styling (default: "text-error")
  * `helper_text` - Helper text shown when no error (optional)

  ## Slots

  * `inner_block` - The actual form input element
  * `label_suffix` - Optional content after the label (e.g., badges)
  """
  attr :label, :string, required: true
  attr :required, :boolean, default: false
  attr :error, :string, default: nil
  attr :error_class, :string, default: "text-error"
  attr :helper_text, :string, default: nil

  slot :inner_block, required: true
  slot :label_suffix

  def form_field(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label">
        <span class="label-text">{@label}</span>
        <span :if={@required} class="label-text-alt text-error">(required)</span>
        {render_slot(@label_suffix)}
      </label>

      {render_slot(@inner_block)}

      <CoreComponents.error :if={@error}>
        {@error}
      </CoreComponents.error>

      <label :if={!@error && @helper_text} class="label">
        <span class="label-text-alt">{@helper_text}</span>
      </label>
    </div>
    """
  end

  @doc """
  Renders a text input for space-separated tags.

  ## Attributes

  * `value` - Current tags as string
  * `name` - Form field name
  * `label` - Input label (optional, default: "Tags")
  * `placeholder` - Input placeholder (optional)
  """
  attr :value, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, default: "Tags"
  attr :placeholder, :string, default: "space separated tags"

  def note_tags_input(assigns) do
    ~H"""
    <.form_field label={@label} helper_text="Enter tags separated by spaces">
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class="input input-bordered w-full"
      />
    </.form_field>
    """
  end

  @doc """
  Renders a select dropdown for choosing a note type.

  ## Attributes

  * `note_types` - List of note type structs with id, name, and description
  * `selected_id` - Currently selected note type ID (optional)
  * `on_change` - Event name to trigger on selection change
  * `error` - Optional error message string (for Ash argument errors)
  """
  attr :note_types, :list, required: true
  attr :selected_id, :string, default: nil
  attr :on_change, :string, required: true
  attr :error, :string, default: nil

  def note_type_selector(assigns) do
    ~H"""
    <.form_field label="Note Type" required={true} error={@error}>
      <select
        name="note_type_id"
        phx-change={@on_change}
        class="select select-bordered w-full"
      >
        <option value="">Select a note type...</option>
        <%= for note_type <- @note_types do %>
          <option value={note_type.id} selected={note_type.id == @selected_id}>
            {note_type.name}{if note_type.description, do: " - #{note_type.description}"}
          </option>
        <% end %>
      </select>
    </.form_field>
    """
  end

  @doc """
  Renders a textarea for markdown content with optional validation error display.

  ## Attributes

  * `field` - Phoenix.HTML.FormField for the text field
  * `rows` - Number of textarea rows (optional, default: 15)
  * `markdown_error` - Optional validation error message
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :rows, :integer, default: 15
  attr :markdown_error, :string, default: nil

  def note_markdown_editor(assigns) do
    ~H"""
    <.form_field label="Markdown Content" error={@markdown_error} error_class="text-warning">
      <textarea
        id={@field.id}
        name={@field.name}
        rows={@rows}
        class="textarea textarea-bordered w-full font-mono text-sm"
        placeholder="Enter markdown content..."
      >{Phoenix.HTML.Form.normalize_value("textarea", @field.value)}</textarea>
    </.form_field>
    """
  end

  @doc """
  Renders a textarea for JSON data with optional validation error display.

  ## Attributes

  * `value` - Current JSON string value
  * `name` - Form field name
  * `rows` - Number of textarea rows (optional, default: 8)
  * `json_error` - Optional validation error message
  """
  attr :value, :string, required: true
  attr :name, :string, required: true
  attr :rows, :integer, default: 8
  attr :json_error, :string, default: nil

  def note_json_data_editor(assigns) do
    ~H"""
    <.form_field
      label="JSON Data"
      error={@json_error}
      helper_text="Optional custom JSON data for this note"
    >
      <textarea
        name={@name}
        rows={@rows}
        class="textarea textarea-bordered w-full font-mono text-sm"
        placeholder="{}"
      >{@value}</textarea>
    </.form_field>
    """
  end

  @doc """
  Renders an interactive directory tree for selecting a parent directory.

  ## Attributes

  * `directories` - List of {directory, children} tuples (nested structure)
  * `selected_id` - ID of currently selected directory
  * `on_select` - Event name to trigger on directory selection
  * `error` - Optional error message to display
  """
  attr :directories, :list, required: true
  attr :selected_id, :string, default: nil
  attr :on_select, :string, required: true
  attr :error, :string, default: nil

  def directory_tree_selector(assigns) do
    ~H"""
    <.form_field
      label="Parent Directory"
      required={true}
      error={@error}
      helper_text="Select the directory where this note will be created"
    >
      <div class="border border-base-300 rounded-lg p-3 bg-base-100 max-h-64 overflow-y-auto">
        <wa-tree id="directory-selector-tree" class="w-full">
          <.selector_tree_item
            :for={{directory, children} <- @directories}
            directory={directory}
            children={children}
            selected_id={@selected_id}
            on_select={@on_select}
          />
        </wa-tree>
        <div :if={@directories == []} class="text-sm text-base-content/60 text-center py-4">
          No directories available
        </div>
      </div>
    </.form_field>
    """
  end

  # Renders a single selectable tree item with recursive children.
  # Private helper component for directory_tree_selector.
  attr :directory, :any, required: true
  attr :children, :list, default: []
  attr :selected_id, :string, default: nil
  attr :on_select, :string, required: true

  defp selector_tree_item(assigns) do
    ~H"""
    <wa-tree-item expanded>
      <wa-icon name="folder" slot="expand-icon"></wa-icon>
      <wa-icon name="folder-open" slot="collapse-icon"></wa-icon>
      <span
        phx-click={@on_select}
        phx-value-id={@directory.id}
        class={[
          "cursor-pointer hover:text-primary transition-colors",
          @directory.id == @selected_id && "font-bold text-primary"
        ]}
      >
        {@directory.name}
      </span>
      <.selector_tree_item
        :for={{child_dir, child_children} <- @children}
        directory={child_dir}
        children={child_children}
        selected_id={@selected_id}
        on_select={@on_select}
      />
    </wa-tree-item>
    """
  end
end
