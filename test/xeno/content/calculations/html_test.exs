defmodule Xeno.Content.Calculations.HtmlTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators
  alias Xeno.Content.Note

  describe "html calculation" do
    test "converts basic markdown to HTML" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "# Heading\n\nSome **bold** text.",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "<h1>"
      assert note.html =~ "Heading"
      assert note.html =~ "<strong>bold</strong>"
    end

    test "converts markdown lists to HTML lists" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "List Note",
            text: "- Item 1\n- Item 2\n- Item 3",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "<ul>"
      assert note.html =~ "<li>"
      assert note.html =~ "Item 1"
      assert note.html =~ "Item 2"
      assert note.html =~ "Item 3"
    end

    test "converts markdown links to HTML links" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Link Note",
            text: "[Example](https://example.com)",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "<a href=\"https://example.com\">Example</a>"
    end

    test "converts code blocks with language to HTML" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Code Note",
            text: "```elixir\ndef hello, do: :world\n```",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "<code"
      assert note.html =~ "def hello"
    end

    test "handles nil text gracefully" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Empty Note",
            text: nil,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html == nil
    end

    test "handles empty string text" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Empty String Note",
            text: "",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html == "" or note.html == nil
    end

    test "handles plain text without markdown" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Plain Note",
            text: "Just plain text",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "<p>"
      assert note.html =~ "Just plain text"
    end

    test "escapes HTML in markdown content for safety" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "HTML Note",
            text: "Some text with <em>HTML</em> tags",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "&lt;em&gt;HTML&lt;/em&gt;"
      assert note.html =~ "Some text"
    end

    test "handles multiline markdown with mixed elements" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      markdown = """
      # Main Heading

      This is a paragraph with **bold** and *italic* text.

      ## Subheading

      - List item 1
      - List item 2

      [A link](https://example.com)
      """

      note =
        generate(
          note(
            name: "Complex Note",
            text: markdown,
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:html])

      assert note.html =~ "<h1>"
      assert note.html =~ "Main Heading"
      assert note.html =~ "<h2>"
      assert note.html =~ "Subheading"
      assert note.html =~ "<strong>bold</strong>"
      assert note.html =~ "<em>italic</em>"
      assert note.html =~ "<ul>"
      assert note.html =~ "<a href=\"https://example.com\">A link</a>"
    end

    test "works with calculation preloaded" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Test Note",
            text: "# Test",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:directory, :note_type, :html])

      assert note.directory.path == "test"
      assert note.note_type.name == "Test Type"
      assert note.html =~ "<h1>"
      assert note.html =~ "Test"
    end

    test "works alongside file_path calculation" do
      note_type = generate(note_type(name: "Test Type"))
      directory = generate(directory(path: "test"))

      note =
        generate(
          note(
            name: "Multi Calc Note",
            filename: "multi_calc_note",
            text: "# Content",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      note = Note.get!(note.id, load: [:file_path, :html])

      assert note.file_path == "test/multi_calc_note"
      assert note.html =~ "<h1>"
      assert note.html =~ "Content"
    end
  end
end
