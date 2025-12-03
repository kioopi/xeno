defmodule XenoWeb.NoteCreateLiveTest do
  use XenoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Xeno.Generators

  setup do
    directory = generate(directory(path: "test_notes", name: "Test Notes"))

    note_type =
      generate(
        note_type(
          name: "Test Type",
          description: "Test note type",
          initial_text: "# Initial Content",
          initial_data: %{"template" => "test"},
          initial_tags: ["template", "test"]
        )
      )

    {:ok, directory: directory, note_type: note_type}
  end

  describe "mount and display" do
    test "mounts create page and displays form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      assert has_element?(view, "form#note-create-form")
    end

    test "loads and displays note types", %{conn: conn, note_type: note_type} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      html = render(view)
      assert html =~ note_type.name
      assert html =~ note_type.description
    end

    test "loads and displays directory tree", %{conn: conn, directory: directory} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      html = render(view)
      assert html =~ directory.name
    end

    test "displays empty form fields initially", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      assert has_element?(view, "input[name='note[name]']")
      assert has_element?(view, "input[name='note[filename]']")
      assert has_element?(view, "textarea[name='note[text]']")
      assert has_element?(view, "input[name='note[tags_string]']")
      assert has_element?(view, "textarea[name='note[data_string]']")
    end

    test "displays page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      assert page_title(view) =~ "Create Note"
    end
  end

  describe "directory selection" do
    test "selecting a directory updates the selected_directory_id", %{
      conn: conn,
      directory: directory
    } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{directory.id}']")
      |> render_click()

      assert view |> element("span[phx-value-id='#{directory.id}'].font-bold") |> has_element?()
    end

    test "selecting a directory clears directory error", %{conn: conn, directory: directory} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{directory.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "Please select a directory"
    end

    test "can select different directories sequentially", %{conn: conn} do
      dir1 = generate(directory(path: "dir1", name: "Directory 1"))
      dir2 = generate(directory(path: "dir2", name: "Directory 2"))

      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{dir1.id}']")
      |> render_click()

      assert view |> element("span[phx-value-id='#{dir1.id}'].font-bold") |> has_element?()

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{dir2.id}']")
      |> render_click()

      assert view |> element("span[phx-value-id='#{dir2.id}'].font-bold") |> has_element?()
      refute view |> element("span[phx-value-id='#{dir1.id}'].font-bold") |> has_element?()
    end
  end

  describe "note type selection" do
    test "selecting a note type updates form fields with template values", %{
      conn: conn,
      note_type: note_type
    } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("select[name='note_type_id']")
      |> render_change(%{"note_type_id" => note_type.id})

      html = render(view)
      assert html =~ note_type.initial_text
      assert html =~ "template"
      assert html =~ "test"
    end

    test "selecting a note type populates tags_string from initial_tags", %{
      conn: conn,
      note_type: note_type
    } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("select[name='note_type_id']")
      |> render_change(%{"note_type_id" => note_type.id})

      html = render(view)
      assert html =~ ~r/value="[^"]*template[^"]*"/
      assert html =~ ~r/value="[^"]*test[^"]*"/
    end

    test "selecting a note type populates data_string from initial_data", %{
      conn: conn,
      note_type: note_type
    } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("select[name='note_type_id']")
      |> render_change(%{"note_type_id" => note_type.id})

      html = render(view)
      assert html =~ "template"
    end

    test "changing note type preserves user-entered name and filename", %{conn: conn} do
      note_type = generate(note_type(name: "Type A", initial_text: "# A"))

      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("form#note-create-form")
      |> render_change(%{"note" => %{"name" => "My Note", "filename" => "my-note"}})

      view
      |> element("select[name='note_type_id']")
      |> render_change(%{"note_type_id" => note_type.id})

      html = render(view)
      assert html =~ "My Note"
      assert html =~ "my-note"
    end
  end

  describe "filename auto-generation" do
    test "filename auto-generates from name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{name: "My Test Note"})
      |> render_change()

      html = render(view)
      assert html =~ "my_test_note"
    end

    test "manual filename edit stops auto-generation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{name: "Test"})
      |> render_change()

      view
      |> form("#note-create-form", note: %{filename: "custom_name"})
      |> render_change()

      view
      |> form("#note-create-form", note: %{name: "Test Updated"})
      |> render_change()

      html = render(view)
      assert html =~ "custom_name"
      refute html =~ "test_updated"
    end

    test "once filename is manually set, it persists even when name changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{name: "First Name", filename: "manual"})
      |> render_change()

      view
      |> form("#note-create-form", note: %{name: "Second Name"})
      |> render_change()

      html = render(view)
      assert html =~ "manual"
      refute html =~ "second_name"
    end
  end

  describe "tags preprocessing" do
    test "converts space-separated tags to array", %{conn: conn, directory: directory} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{directory.id}']")
      |> render_click()

      view
      |> form("#note-create-form", note: %{
        name: "Test Note",
        filename: "test",
        tags_string: "tag1 tag2 tag3"
      })
      |> render_change()

      form_source = :sys.get_state(view.pid).socket.assigns.form.source
      assert form_source.params["tags"] == ["tag1", "tag2", "tag3"]
    end

    test "handles empty tags string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{tags_string: ""})
      |> render_change()

      form_source = :sys.get_state(view.pid).socket.assigns.form.source
      assert form_source.params["tags"] == []
    end
  end

  describe "data preprocessing" do
    test "converts valid JSON string to map", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      json_string = ~s({"key": "value", "count": 42})

      view
      |> form("#note-create-form", note: %{data_string: json_string})
      |> render_change()

      form_source = :sys.get_state(view.pid).socket.assigns.form.source
      assert form_source.params["data"] == %{"key" => "value", "count" => 42}
    end

    test "handles empty data string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{data_string: ""})
      |> render_change()

      form_source = :sys.get_state(view.pid).socket.assigns.form.source
      assert form_source.params["data"] == %{}
    end

    test "shows error for invalid JSON", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{data_string: "{invalid"})
      |> render_change()

      form_source = :sys.get_state(view.pid).socket.assigns.form.source
      refute form_source.params["data"]

      socket_assigns = :sys.get_state(view.pid).socket.assigns
      assert socket_assigns.json_error =~ "Invalid JSON"
    end
  end

  describe "cancel handler" do
    test "cancel navigates to home", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("#cancel-btn")
      |> render_click()

      assert_redirect(view, ~p"/")
    end
  end

  describe "form submission" do
    test "creates note with all fields", %{conn: conn, directory: directory, note_type: note_type} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{directory.id}']")
      |> render_click()

      view
      |> element("select[name='note_type_id']")
      |> render_change(%{"note_type_id" => note_type.id})

      view
      |> form("#note-create-form", note: %{
        name: "My Test Note",
        filename: "my_test_note",
        text: "# Test Content",
        tags_string: "tag1 tag2",
        data_string: ~s({"key": "value"})
      })
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ "/notes/"

      [_match, note_id] = Regex.run(~r/\/notes\/([a-f0-9-]+)/, path)

      {:ok, note} = Xeno.Content.Note.get(note_id)
      assert note.name == "My Test Note"
      assert note.filename == "my_test_note"
      assert note.text == "# Test Content"
      assert note.tags == ["tag1", "tag2"]
      assert note.data == %{"key" => "value"}
      assert note.directory_id == directory.id
      assert note.note_type_id == note_type.id
    end

    test "shows error when directory not selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", note: %{
        name: "Test",
        filename: "test"
      })
      |> render_submit()

      html = render(view)
      # Should show Ash validation error for directory_id argument
      assert html =~ "required" || html =~ "must be present"
    end

    test "shows error when note type not selected", %{conn: conn, directory: directory} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> element("span[phx-click='select_directory'][phx-value-id='#{directory.id}']")
      |> render_click()

      view
      |> form("#note-create-form", note: %{
        name: "Test",
        filename: "test"
      })
      |> render_submit()

      html = render(view)
      # Should show Ash validation error for note_type_id argument
      assert html =~ "required" || html =~ "must be present"
    end
  end
end
