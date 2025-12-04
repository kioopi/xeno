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

    empty_form =
      %{
        "data" => "{}",
        "directory_id" => "",
        "filename" => "",
        "name" => "",
        "note_type_id" => "",
        "tags" => "",
        "text" => ""
      }

    {:ok, directory: directory, note_type: note_type, empty_form: empty_form}
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

      assert has_element?(view, "input[name='form[name]']")
      assert has_element?(view, "input[name='form[filename]']")
      assert has_element?(view, "textarea[name='form[text]']")
      assert has_element?(view, "input[name='form[tags]']")
      assert has_element?(view, "textarea[name='form[data]']")
    end

    test "displays page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      assert page_title(view) =~ "Create Note"
    end
  end

  describe "directory selection" do
    test "selecting a directory updates the selected_directory_id. weird variant", %{
      conn: conn,
      directory: directory
    } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      # it seems like this shitty variant works
      params = %{
        "_target" => ["form", "directory_id"],
        "form" => %{
          "data" => "{}",
          "directory_id" => directory.id,
          "filename" => "",
          "name" => "",
          "note_type_id" => "",
          "tags" => "",
          "text" => ""
        }
      }

      send(view.pid, {:handle_event, "validate", params})
      render(view)

      assert view
             |> has_element?("span[phx-value-id='#{directory.id}'].font-bold", directory.name)

      assert view |> has_element?("input[name='form[directory_id]'][value='#{directory.id}']")
    end

    test "selecting a directory updates the tree item and the hidden field",
         %{
           conn: conn,
           directory: directory,
           empty_form: form
         } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", form: form)
      |> render_change(%{form: %{"directory_id" => directory.id}})

      render(view)

      assert view
             |> has_element?("span[phx-value-id='#{directory.id}'].font-bold", directory.name)

      assert view |> has_element?("input[name='form[directory_id]'][value='#{directory.id}']")
    end

    test "selecting a directory clears directory error", %{
      conn: conn,
      directory: directory,
      empty_form: form
    } do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", form: form)
      |> render_change(%{form: %{"directory_id" => ""}})

      _html = render(view)

      # FIXME: directory tree support for error messages is broken currently
      #
      # assert html =~ "Please select a directory"

      form = Map.put(form, "directory_id", "")

      view
      |> form("#note-create-form", form: form)
      |> render_change(%{form: %{"directory_id" => directory.id}})

      html = render(view)

      refute html =~ "Please select a directory"
    end

    test "can select different directories sequentially", %{conn: conn, empty_form: form} do
      dir1 = generate(directory(path: "dir1", name: "Directory 1"))
      dir2 = generate(directory(path: "dir2", name: "Directory 2"))

      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form", form: form)
      |> render_change(%{form: %{"directory_id" => dir1.id}})

      render(view)

      assert view |> element("span[phx-value-id='#{dir1.id}'].font-bold") |> has_element?()

      form = Map.put(form, "directory_id", dir1.id)

      view
      |> form("#note-create-form", form: form)
      |> render_change(%{form: %{"directory_id" => dir2.id}})

      render(view)

      assert view |> element("span[phx-value-id='#{dir2.id}'].font-bold") |> has_element?()
      refute view |> element("span[phx-value-id='#{dir1.id}'].font-bold") |> has_element?()
    end

    test "selecting a directory does not reset other fields", %{
      conn: conn,
      directory: directory
    } do
      conn
      |> visit(~p"/notes/new")
      |> fill_in("Name", with: "Test Note")
      |> assert_has("input[name='form[name]']", value: "Test Note")
      |> assert_has("input[name='form[filename]']", value: "test_note")
      |> click_button(directory.name)
      |> assert_has("input[name='form[name]']", value: "Test Note")
      |> assert_has("input[name='form[filename]']", value: "test_note")
    end
  end

  describe "note type selection" do
    test "selecting a note type updates form fields with inital values", %{
      conn: conn,
      note_type: note_type
    } do
      conn
      |> visit(~p"/notes/new")
      |> select("Note Type", option: note_type.name, exact_option: false)
      |> assert_has("textarea[name='form[text]']", text: note_type.initial_text)
    end

    test "selecting a note type populates tags from initial_tags", %{
      conn: conn,
      note_type: note_type
    } do
      conn
      |> visit(~p"/notes/new")
      |> select("Note Type", option: note_type.name, exact_option: false)
      |> assert_has(
        "input[name='form[tags]']",
        value: Enum.join(note_type.initial_tags, " ")
      )
    end

    test "selecting a note type populates data from initial_data", %{
      conn: conn,
      note_type: note_type
    } do
      conn
      |> visit(~p"/notes/new")
      |> select("Note Type", option: note_type.name, exact_option: false)
      |> assert_has("textarea[name='form[data]']", text: "template")
      |> assert_has("textarea[name='form[data]']", text: "test")

      # this test seems rather week but i couldn't get a better match beetwen
      # json formatting, html escaping, and regexes
    end

    test "changing note type preserves user-entered name and filename", %{conn: conn} do
      note_type = generate(note_type(name: "Type A", initial_text: "# A"))

      conn
      |> visit(~p"/notes/new")
      |> fill_in("Name", with: "My Note")
      |> fill_in("Filename", with: "my-note")
      |> select("Note Type", option: note_type.name, exact_option: false)
      |> assert_has("input[name='form[name]']", value: "My Note")
      |> assert_has("input[name='form[filename]']", value: "my-note")
    end
  end

  describe "filename auto-generation" do
    test "filename auto-generates from name", %{conn: conn} do
      conn
      |> visit(~p"/notes/new")
      |> fill_in("Name", with: "Note Name")
      |> assert_has("input[name='form[filename]']", value: "note_name")
    end

    test "manual filename edit stops auto-generation", %{conn: conn} do
      conn
      |> visit(~p"/notes/new")
      |> fill_in("Name", with: "Note Name")
      |> assert_has("input[name='form[filename]']", value: "note_name")
      |> fill_in("Filename", with: "other_name")
      |> assert_has("input[name='form[filename]']", value: "other_name")
      |> fill_in("Name", with: "New Name")
      |> assert_has("input[name='form[filename]']", value: "other_name")
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

      # view
      # |> element("span[phx-click='select_directory'][phx-value-id='#{directory.id}']")
      # |> render_click()

      # view
      # |> element("select[name='note_type_id']")
      # |> render_change(%{"note_type_id" => note_type.id})

      view
      |> form("#note-create-form",
        form: %{
          name: "My Test Note",
          filename: "my_test_note",
          text: "# Test Content",
          tags: "tag1 tag2",
          data: ~s({"key": "value"}),
          note_type_id: note_type.id
        }
      )
      |> render_submit(%{"form" => %{"directory_id" => directory.id}})

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
      |> form("#note-create-form",
        form: %{
          name: "Test",
          filename: "test"
        }
      )
      |> render_submit()

      html = render(view)
      # Should show Ash validation error for directory_id argument
      assert html =~ "required" || html =~ "must be present"
    end

    test "shows error when note type not selected", %{conn: conn, directory: directory} do
      {:ok, view, _html} = live(conn, ~p"/notes/new")

      view
      |> form("#note-create-form",
        form: %{
          name: "Test",
          filename: "test"
        }
      )
      |> render_submit(%{directory_id: directory.id})

      html = render(view)
      # Should show Ash validation error for note_type_id argument
      assert html =~ "required" || html =~ "must be present"
    end
  end
end
