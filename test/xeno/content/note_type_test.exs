defmodule Xeno.Content.NoteTypeTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.NoteType

  describe "create/1" do
    test "creates note type with all fields" do
      attrs = %{
        name: "Meeting Notes",
        description: "Template for meeting notes",
        initial_text: "# Meeting Notes\n\n## Attendees\n\n## Agenda\n",
        initial_data: %{"template_version" => "1.0"},
        initial_tags: ["meeting", "work"]
      }

      assert {:ok, note_type} = NoteType.create(attrs)
      assert note_type.name == "Meeting Notes"
      assert note_type.description == "Template for meeting notes"
      assert note_type.initial_text =~ "Meeting Notes"
      assert note_type.initial_data == %{"template_version" => "1.0"}
      assert note_type.initial_tags == ["meeting", "work"]
    end

    test "creates note type with minimal fields" do
      assert {:ok, note_type} = NoteType.create(%{name: "Simple"})
      assert note_type.name == "Simple"
      assert is_nil(note_type.description)
      assert is_nil(note_type.initial_text)
    end

    test "fails when name is not unique" do
      assert {:ok, _} = NoteType.create(%{name: "Duplicate"})
      assert {:error, error} = NoteType.create(%{name: "Duplicate"})

      assert Exception.message(error) =~ "unique"
    end

    test "fails when name is missing" do
      assert {:error, error} = NoteType.create(%{description: "No name"})

      assert Exception.message(error) =~ "required"
    end
  end

  describe "update/2" do
    test "updates note type fields" do
      note_type = generate(note_type(name: "Original"))

      assert {:ok, updated} =
               NoteType.update(note_type, %{
                 name: "Updated",
                 description: "New description"
               })

      assert updated.name == "Updated"
      assert updated.description == "New description"
    end
  end

  describe "by_name/1" do
    test "finds note type by name" do
      note_type = generate(note_type(name: "Findable"))
      assert {:ok, found} = NoteType.by_name("Findable")
      assert found.id == note_type.id
    end

    test "returns error when not found" do
      assert {:error, error} = NoteType.by_name("NonExistent")
      assert Exception.message(error) =~ "not found"
    end
  end

  describe "timestamps" do
    test "sets inserted_at and updated_at on creation" do
      note_type = generate(note_type(name: "Timestamped"))

      assert %DateTime{} = note_type.inserted_at
      assert %DateTime{} = note_type.updated_at
    end
  end

  describe "note_params" do
    test "returns params for note changesets" do
      note_type =
        generate(
          note_type(initial_tags: ["1", "2"], initial_text: "hello", initial_data: %{w: 0})
        )

      note_type = Ash.load!(note_type, :note_params)

      assert note_type.note_params == %{
               "tags" => ["1", "2"],
               "text" => "hello",
               "data" => %{"w" => 0}
             }
    end
  end
end
