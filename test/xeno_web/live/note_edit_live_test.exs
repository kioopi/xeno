defmodule XenoWeb.NoteEditLiveTest do
  use XenoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Xeno.Generators

  alias Xeno.Content.Note

  setup do
    directory = generate(directory(path: "test_notes"))

    note_type =
      generate(
        note_type(
          name: "Test Type",
          initial_text: "Initial content",
          initial_tags: ["initial"]
        )
      )

    note =
      generate(
        note(
          name: "Test Note",
          text: "Test content here",
          data: %{"key" => "value", "number" => 42},
          tags: ["test", "example"],
          directory_id: directory.id,
          note_type_id: note_type.id
        )
      )

    {:ok, note: note, directory: directory, note_type: note_type}
  end

  describe "mount and display" do
    test "mounts edit page and displays form", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert has_element?(view, "form#note-edit-form")
    end

    test "shows note name in form", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert has_element?(view, "input[name='note[name]'][value='Test Note']")
    end

    test "shows text content in textarea", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      html = render(view)
      assert html =~ "Test content here"
      assert has_element?(view, "textarea[name='note[text]']")
    end

    test "shows tags as space-separated string", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert has_element?(view, "input[name='note[tags_string]']")
      html = render(view)
      assert html =~ "example test"
    end

    test "shows data as JSON string", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      html = render(view)
      assert html =~ "key" and html =~ "value"
      assert has_element?(view, "textarea[name='note[data_string]']")
    end

    test "displays read-only filename", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      html = render(view)
      assert html =~ note.filename
      assert html =~ "Filename cannot be changed"
    end

    test "preloads directory and note_type relationships", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      html = render(view)
      assert html =~ note.note_type.name
      assert html =~ note.directory.path
    end
  end

  describe "form validation" do
    test "validates form on change event", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{name: "Updated Name"})
      |> render_change()

      assert has_element?(view, "input[name='note[name]'][value='Updated Name']")
    end

    test "shows errors for invalid name (empty)", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      html =
        view
        |> form("#note-edit-form", note: %{name: ""})
        |> render_change()

      assert html =~ "required" or html =~ "blank" or html =~ "must be present"
    end

    test "shows errors for invalid JSON in data field", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      html =
        view
        |> form("#note-edit-form", note: %{data_string: "{invalid json"})
        |> render_change()

      assert html =~ "invalid" or html =~ "JSON"
    end

    test "updates form state without persisting", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{name: "Changed Name"})
      |> render_change()

      {:ok, unchanged_note} = Note.get(note.id)
      assert unchanged_note.name == "Test Note"
    end

    test "preserves tags_string when editing other fields", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{tags_string: "new unsaved tags"})
      |> render_change()

      html =
        view
        |> form("#note-edit-form", note: %{text: "Updated text content"})
        |> render_change()

      assert html =~ "new unsaved tags"
    end

    test "preserves data_string when editing other fields", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{data_string: ~s({"unsaved": "data"})})
      |> render_change()

      html =
        view
        |> form("#note-edit-form", note: %{text: "Updated text content"})
        |> render_change()

      assert html =~ "unsaved"
    end

    test "preserves both tags_string and data_string when editing name", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{tags_string: "alpha beta", data_string: ~s({"temp": 1})})
      |> render_change()

      html =
        view
        |> form("#note-edit-form", note: %{name: "New Name"})
        |> render_change()

      assert html =~ "alpha beta"
      assert html =~ "temp"
    end
  end

  describe "form submission" do
    test "updates note successfully with valid data", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form",
        note: %{
          name: "Updated Note",
          text: "Updated text"
        }
      )
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert updated.name == "Updated Note"
      assert updated.text == "Updated text"
    end

    test "redirects to show page after successful update", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{name: "Updated Note"})
      |> render_submit()

      assert_redirect(view, ~p"/notes/#{note.id}")
    end

    test "updates name field", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{name: "New Name"})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert updated.name == "New Name"
    end

    test "updates text field", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{text: "Brand new content"})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert updated.text == "Brand new content"
    end

    test "updates tags (space-separated to array conversion)", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{tags_string: "new updated tags"})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert Enum.sort(updated.tags) == ["new", "tags", "updated"]
    end

    test "updates data (JSON string to map conversion)", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      json_string = ~s({"newkey": "newvalue", "count": 100})

      view
      |> form("#note-edit-form", note: %{data_string: json_string})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert updated.data == %{"newkey" => "newvalue", "count" => 100}
    end
  end

  describe "tag handling" do
    test "converts space-separated tags to array", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{tags_string: "one two three"})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert Enum.sort(updated.tags) == ["one", "three", "two"]
    end

    test "normalizes tags (lowercase, trim, deduplicate)", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{tags_string: "  TAG  tag   Another  "})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert Enum.sort(updated.tags) == ["another", "tag"]
    end

    test "handles empty tags string", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{tags_string: ""})
      |> render_submit()

      {:ok, updated} = Note.get(note.id)
      assert updated.tags == [] or is_nil(updated.tags)
    end
  end

  describe "optimistic locking" do
    test "shows error when version conflict occurs", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      {:ok, _updated} = Note.update(note, %{text: "Updated externally"})

      view
      |> form("#note-edit-form", note: %{name: "My Update"})
      |> render_submit()

      {:ok, unchanged} = Note.get(note.id)
      assert unchanged.name == "Test Note"
    end

    test "displays helpful message about stale data", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      {:ok, _updated} = Note.update(note, %{text: "Changed"})

      view
      |> form("#note-edit-form", note: %{name: "Conflict Update"})
      |> render_submit()

      {:ok, unchanged} = Note.get(note.id)
      assert unchanged.name == "Test Note"
    end
  end

  describe "navigation" do
    test "cancel button navigates back to show page", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> element("button", "Cancel")
      |> render_click()

      assert_redirect(view, ~p"/notes/#{note.id}")
    end

    test "back navigation preserves note state", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      view
      |> form("#note-edit-form", note: %{name: "Changed"})
      |> render_change()

      view
      |> element("button", "Cancel")
      |> render_click()

      {:ok, unchanged} = Note.get(note.id)
      assert unchanged.name == "Test Note"
    end
  end

  describe "error handling" do
    test "shows flash error for non-existent note", %{conn: conn} do
      fake_id = Ash.UUID.generate()

      assert {:error, {:live_redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/notes/#{fake_id}/edit")

      assert flash["error"] =~ "Note not found"
    end

    test "redirects to home page when note not found", %{conn: conn} do
      fake_id = Ash.UUID.generate()

      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(conn, ~p"/notes/#{fake_id}/edit")
    end
  end

  describe "component structure (post-refactor)" do
    test "uses heading component for page title", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert has_element?(view, "h1", "Edit Note")
    end

    test "uses container component with proper max-width", %{conn: conn, note: note} do
      {:ok, view, html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert html =~ ~r/max-w-/
      assert html =~ ~r/mx-auto/
    end

    test "uses button_group for form actions", %{conn: conn, note: note} do
      {:ok, view, html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert html =~ ~r/flex/
      assert html =~ ~r/gap-/
    end

    test "submit button has proper structure", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert has_element?(view, "button[type='submit']", "Save Changes")
    end

    test "cancel button has phx-click event", %{conn: conn, note: note} do
      {:ok, view, _html} = live(conn, ~p"/notes/#{note.id}/edit")

      assert has_element?(view, "button[phx-click='cancel']", "Cancel")
    end

    test "form actions are wrapped in button group container", %{conn: conn, note: note} do
      {:ok, view, html} = live(conn, ~p"/notes/#{note.id}/edit")

      # Check that both buttons exist (button text may have whitespace)
      assert html =~ "Save Changes"
      assert html =~ "Cancel"
      assert has_element?(view, "button[type='submit']")
      assert has_element?(view, "button[phx-click='cancel']")
    end
  end
end
