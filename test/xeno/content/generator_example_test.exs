defmodule Xeno.Content.GeneratorExampleTest do
  @moduledoc """
  Example test demonstrating how to use the Xeno.Generators module.

  This file shows various ways to generate test data for Notes, NoteTypes, and Directories.
  """
  use Xeno.DataCase, async: true

  import Xeno.Generators

  describe "basic generator usage" do
    test "generate a directory with defaults" do
      directory = generate(directory())

      assert directory.id
      assert directory.path
      assert directory.name
    end

    test "generate a directory with custom path" do
      directory = generate(directory(path: "custom/path"))

      assert directory.path == "custom/path"
      assert directory.name == "Path"
    end

    test "generate a note type with defaults" do
      note_type = generate(note_type())

      assert note_type.id
      assert note_type.name
    end

    test "generate a note type with custom attributes" do
      note_type =
        generate(
          note_type(
            name: "Custom Type",
            description: "A custom template",
            initial_text: "# Template",
            initial_tags: ["custom", "test"]
          )
        )

      assert note_type.name == "Custom Type"
      assert note_type.description == "A custom template"
      assert note_type.initial_text == "# Template"
      assert note_type.initial_tags == ["custom", "test"]
    end

    test "generate a note with defaults (auto-creates directory and note_type)" do
      note = generate(note())

      assert note.id
      assert note.name
      assert note.directory_id
      assert note.note_type_id
    end

    test "generate a note with custom name only" do
      note = generate(note(name: "My Custom Note"))

      assert note.name == "My Custom Note"
      assert note.directory_id
      assert note.note_type_id
    end

    test "generate a note with explicit relationships" do
      directory = generate(directory())
      note_type = generate(note_type())

      note =
        generate(
          note(
            name: "My Note",
            directory_id: directory.id,
            note_type_id: note_type.id
          )
        )

      assert note.id
      assert note.name == "My Note"
      assert note.directory_id == directory.id
      assert note.note_type_id == note_type.id
    end

    test "generate a note with all custom attributes" do
      note =
        generate(
          note(
            name: "Complete Note",
            text: "This is the content",
            data: %{"priority" => "high", "status" => "active"},
            tags: ["important", "work"]
          )
        )

      assert note.name == "Complete Note"
      assert note.text == "This is the content"
      assert note.data == %{"priority" => "high", "status" => "active"}
      assert note.tags == ["important", "work"]
      # Directory and note_type auto-generated
      assert note.directory_id
      assert note.note_type_id
    end
  end

  describe "generate_many usage" do
    test "generate multiple note types with unique names" do
      # Create note types with explicit unique names
      note_types =
        [
          generate(note_type(name: "Type 1")),
          generate(note_type(name: "Type 2")),
          generate(note_type(name: "Type 3"))
        ]

      assert length(note_types) == 3
      assert Enum.all?(note_types, & &1.id)
    end

    test "generate multiple notes" do
      # All notes will share the same auto-generated directory and note_type
      notes = generate_many(note(), 3)

      assert length(notes) == 3
      assert Enum.all?(notes, & &1.id)
      # Verify they share the same directory and note_type
      [first | rest] = notes
      assert Enum.all?(rest, &(&1.directory_id == first.directory_id))
      assert Enum.all?(rest, &(&1.note_type_id == first.note_type_id))
    end

    test "generate multiple notes with same type" do
      directory = generate(directory())
      note_type = generate(note_type(name: "Shared Type"))

      notes =
        generate_many(
          note(
            directory_id: directory.id,
            note_type_id: note_type.id
          ),
          3
        )

      assert length(notes) == 3
      assert Enum.all?(notes, &(&1.note_type_id == note_type.id))
    end
  end
end
