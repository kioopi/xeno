defmodule XenoWeb.NoteComponentsTest do
  use XenoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component
  alias XenoWeb.NoteComponents

  describe "note_tags_input/1" do
    test "renders text input with label and placeholder" do
      assigns = %{value: "test tag", name: "note[tags_string]"}

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_tags_input
          value={@value}
          name={@name}
          label="Tags"
          placeholder="space separated tags"
        />
        """)

      assert html =~ "Tags"
      assert html =~ "space separated tags"
      assert html =~ ~r/name="note\[tags_string\]"/
      assert html =~ "test tag"
    end

    test "renders with helper text about space-separated format" do
      assigns = %{value: "", name: "note[tags_string]"}

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_tags_input value={@value} name={@name} label="Tags" />
        """)

      assert html =~ "space" or html =~ "separated"
    end
  end

  describe "note_type_selector/1" do
    test "renders select element with options" do
      assigns = %{
        note_types: [
          %{id: "1", name: "Type 1", description: "First type"},
          %{id: "2", name: "Type 2", description: "Second type"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_type_selector
          note_types={@note_types}
          name="note_type"
          value={nil}
        />
        """)

      assert html =~ "<select"
      assert html =~ "Type 1"
      assert html =~ "Type 2"
    end

    test "shows descriptions for note types" do
      assigns = %{
        note_types: [
          %{id: "1", name: "Type 1", description: "First type description"}
        ]
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_type_selector
          note_types={@note_types}
          name="note_type"
          value={nil}
        />
        """)

      assert html =~ "First type description"
    end
  end

  describe "note_markdown_editor/1" do
    test "renders textarea for markdown content" do
      assigns = %{
        field: %Phoenix.HTML.FormField{
          id: "note_text",
          name: "note[text]",
          value: "# Hello",
          errors: [],
          field: :text,
          form: %Phoenix.HTML.Form{}
        }
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_markdown_editor field={@field} rows={10} />
        """)

      assert html =~ "<textarea"
      assert html =~ ~r/name="note\[text\]"/
      assert html =~ "# Hello"
    end

    # Is there really such a thing as invalid markdown?
    @tag :skip
    test "displays markdown validation error when present" do
      assigns = %{
        field: %Phoenix.HTML.FormField{
          id: "note_text",
          name: "note[text]",
          value: "hello\n# h1\n# h2",
          errors: [],
          field: :text,
          form: %Phoenix.HTML.Form{}
        }
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_markdown_editor field={@field} />
        """)

      assert html =~ "Invalid markdown syntax"
    end
  end

  describe "note_json_data_editor/1" do
    test "renders textarea for JSON data" do
      assigns = %{value: ~s|{"key": "value"}|, name: "note[data_string]"}

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_json_data_editor value={@value} name={@name} rows={8} />
        """)

      assert html =~ "<textarea"
      assert html =~ ~r/name="note\[data_string\]"/
      assert html =~ "key"
    end

    test "displays JSON validation error when present" do
      assigns = %{
        value: "{invalid",
        name: "note[data_string]",
        json_error: "Invalid JSON syntax"
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_json_data_editor
          value={@value}
          name={@name}
          json_error={@json_error}
        />
        """)

      assert html =~ "Invalid JSON syntax"
    end

    test "shows placeholder when value is empty" do
      assigns = %{value: "", name: "note[data_string]"}

      html =
        rendered_to_string(~H"""
        <NoteComponents.note_json_data_editor value={@value} name={@name} />
        """)

      assert html =~ "Optional custom JSON data"
    end
  end

  describe "directory_tree_selector/1" do
    test "renders tree structure with directories" do
      assigns = %{
        directories: [
          {%{id: "1", name: "Root", path: "root"},
           [
             {%{id: "2", name: "Child", path: "root.child"}, []}
           ]}
        ],
        field: %Phoenix.HTML.FormField{
          id: "directory_id",
          name: "note[directory_id]",
          value: nil,
          errors: [],
          field: :directory_id,
          form: %Phoenix.HTML.Form{}
        }
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.directory_tree_selector
          directories={@directories}
          field={@field}
        />
        """)

      assert html =~ "Root"
      assert html =~ "Child"
      assert html =~ "<wa-tree"
    end

    test "marks selected directory with styling" do
      assigns = %{
        directories: [
          {%{id: "1", name: "Root", path: "root"}, []},
          {%{id: "2", name: "Other", path: "other"}, []}
        ],
        field: %Phoenix.HTML.FormField{
          id: "directory_id",
          name: "note[directory_id]",
          value: "1",
          errors: [],
          field: :directory_id,
          form: %Phoenix.HTML.Form{}
        }
      }

      html =
        rendered_to_string(~H"""
        <NoteComponents.directory_tree_selector
          directories={@directories}
          field={@field}
        />
        """)

      assert html =~ "Root"
      assert html =~ "selected" or html =~ "font-bold" or html =~ "primary"
    end
  end
end
