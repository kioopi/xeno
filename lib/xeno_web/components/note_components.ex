defmodule XenoWeb.NoteComponents do
  @moduledoc """
  Reusable components for note creation and editing forms.
  """
  use XenoWeb, :html
  alias XenoWeb.CoreComponents
  alias Xeno.Content.Note

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
  attr :label_for, :string, required: true
  attr :required, :boolean, default: false
  attr :errors, :list, default: []
  attr :error_class, :string, default: "text-error"
  attr :helper_text, :string, default: nil

  slot :inner_block, required: true
  slot :label_suffix

  def form_field(assigns) do
    ~H"""
    <div class="form-control w-full">
      <label class="label" for={@label_for}>
        <span class="label-text">{@label}</span>
        <span :if={@required} class="label-text-alt text-error">(required)</span>
        {render_slot(@label_suffix)}
      </label>

      {render_slot(@inner_block)}

      <CoreComponents.error :for={msg <- @errors}>{msg}</CoreComponents.error>

      <label :if={!@errors && @helper_text} class="label">
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
  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :label, :string, default: "Tags"

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any

  attr :errors, :list, default: []
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step),
    default: %{placeholder: "space separated tags"}

  def note_tags_input(assigns) do
    assigns =
      assigns
      |> assign(:attrs, assigns_to_attributes(assigns))

    ~H"""
      <CoreComponents.input
        {@attrs}
        type="text"
      />
    """
  end

  @doc """
  Renders a select dropdown for choosing a note type.

  ## Attributes

  * `note_types` - List of note type structs with id, name, and description
  """
  attr :note_types, :list, required: true

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :label, :string, default: "Note Type"

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any

  attr :errors, :list, default: []
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"
  attr :prompt, :string, default: "Select Note Type", doc: "the prompt for the select"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern readonly required rows size step)

  def note_type_selector(assigns) do
    assigns =
      assigns
      |> assign(:attrs, assigns_to_attributes(assigns))

    ~H"""
    <CoreComponents.input
      {@attrs}
      type="select"
      options={note_type_options(@note_types)} 
      />
    """
  end

  defp note_type_options(note_types) do
    [
      [key: "Select Note Type", value: "", disabled: true, selected: true]
      | Enum.map(note_types, fn nt ->
          {note_type_label(nt), nt.id}
        end)
    ]
  end

  defp note_type_label(note_type) do
    note_type.name <> ((note_type.description && " - #{note_type.description}") || "")
  end

  @doc """
  Renders a textarea for markdown content with validation.

  ## Attributes

  * `field` - Phoenix.HTML.FormField for the text field
  * `rows` - Number of textarea rows (optional, default: 15)
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :rows, :integer, default: 15

  # TODO accept all CodeComponent input attributes like note_type_selector
  def note_markdown_editor(assigns) do
    ~H"""
    <CoreComponents.input
      type="textarea"
      field={@field}
      label="Markdown Content"
      class="textarea textarea-bordered w-full font-mono text-sm"

      />
    """
  end

  @doc """
  Renders a textarea for JSON data with validation.

  ## Attributes

  * `field` - Phoenix.HTML.FormField for the data_string field
  * `rows` - Number of textarea rows (optional, default: 8)
  """
  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :label, :string, default: "Note Type"

  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any

  attr :errors, :list, default: []
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"
  attr :prompt, :string, default: "Select Note Type", doc: "the prompt for the select"
  attr :rows, :integer, default: 8

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern readonly placeholder required rows size step),
    default: %{placeholder: "Optional custom JSON data for this note"}

  # TODO: this first needs to become a phoenix input
  # and later a better JSON editor can be integrated
  def note_json_data_editor(assigns) do
    assigns =
      assigns
      |> assign(:attrs, assigns_to_attributes(assigns))

    ~H"""
    <CoreComponents.input
        type="textarea"
        {@attrs}
      />
    """
  end

  def json_data_to_string(assigns) do
    if Map.has_key?(assigns, :value) do
      assigns |> assign(:value, Note.json_string(assigns.value))
    else
      if Map.has_key?(assigns, :field) do
        assigns =
          assigns
          |> assign(:field, Map.update(assigns.field, :value, "{}", &Note.json_string(&1)))
          |> assign(:value, Note.json_string(assigns.field.value))

        assigns
      else
        assigns
      end
    end
  end

  @doc """
  Renders an interactive directory tree for selecting a parent directory.

  ## Attributes

  * `directories` - List of {directory, children} tuples (nested structure)
  """
  attr :directories, :list, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  # attr :on_select, :string, required: true
  # attr :error, :string, default: nil
  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def directory_tree_selector(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []
    translated_errors = Enum.map(errors, &CoreComponents.translate_error(&1))

    assigns =
      assigns
      |> assign(field: nil)
      |> assign(id: field.id)
      |> assign(errors: translated_errors)
      |> assign_new(:name, fn -> field.name end)
      |> assign_new(:value, fn -> field.value end)

    ~H"""
    <.form_field
      label="Directory"
      required={true}
      errors={@errors}
      label_for="form_directory_id"
      helper_text="Select the directory where this note will be created"
    >
      <div id={@name <> "-directory-selector"} data-field-name={@name} class="border border-base-300 rounded-lg p-3 bg-base-100 max-h-64 overflow-y-auto">
        <input type="hidden" name={@name} id="form_directory_id" class="dirtree-input" value={@value} disabled={@rest[:disabled]} />
        <wa-tree class="w-full dirtree-tree">
          <.selector_tree_item
            :for={{directory, children} <- @directories}
            directory={directory}
            children={children}
            selected_id={@value}
            name={@name}
          />
        </wa-tree>
        <div :if={@directories == []} class="text-sm text-base-content/60 text-center py-4">
          No directories available
        </div>
      </div>
    </.form_field>
    """
  end

  # this is the unused colocated hook for the directory tree selector
  # changed to to use phx event because of testability issues
  # Still think the hook would be more clean.
  # Best solution would be to have a form-aware wa-tree component
  def dirtree_hook(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".DirectoryTree">
    export default {
      mounted() {
        const fieldName = this.el.dataset.fieldName;
        this.el.querySelector('.dirtree-tree').addEventListener("wa-selection-change", e => {
           if (e.detail.selection.length == 1) {
             const selection = e.detail.selection[0].dataset.directoryId;
             const input = this.el.querySelector('.dirtree-input');

             if (input && selection) {
               input.value = selection;
               input.dispatchEvent(
                 new Event("input", {bubbles: true})
               )
             }
           }
        })
      }
    }
    </script>
    """
  end

  # JS.set_attribute({"value", @directory.id}, to: "input[name='#{@name}']")
  # |> JS.dispatch("input", to: "input[name='#{@name}']")

  # Renders a single selectable tree item with recursive children.
  # Private helper component for directory_tree_selector.
  attr :directory, :any, required: true
  attr :children, :list, default: []
  attr :selected_id, :string, default: nil
  attr :name, :string, required: true

  defp selector_tree_item(assigns) do
    ~H"""
    <wa-tree-item expanded data-directory-id={@directory.id}>
      <wa-icon name="folder" slot="expand-icon"></wa-icon>
      <wa-icon name="folder-open" slot="collapse-icon"></wa-icon>
      <span
        phx-value-id={@directory.id}
        role="button"
        class={[
          "select-directory cursor-pointer hover:text-primary transition-colors",
          @directory.id == @selected_id && "font-bold text-primary"
        ]}
        phx-click="directory_id_changed"
      >
        {@directory.name}
      </span>
      <.selector_tree_item
        :for={{child_dir, child_children} <- @children}
        directory={child_dir}
        children={child_children}
        selected_id={@selected_id}
        name={@name}
      />
    </wa-tree-item>
    """
  end
end
