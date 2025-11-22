defmodule Xeno.Sync.ExporterTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Sync.Exporter

  setup do
    directory = generate(directory(path: "projects/web_app"))

    note_type = generate(
      note_type(
        name: "Technical Note",
        initial_text: "# Template",
        initial_data: %{"category" => "tech"},
        initial_tags: ["engineering"]
      )
    )

    {:ok, note} =
      Xeno.Content.Note.create(%{
        name: "Architecture Notes",
        filename: "architecture.md",
        text: "# System Architecture\n\nThis is the architecture documentation.",
        data: %{"status" => "draft", "version" => "1.0"},
        tags: ["architecture", "design"],
        directory_id: directory.id,
        note_type_id: note_type.id
      })

    # Reload with relationships
    note = Ash.get!(Xeno.Content.Note, note.id, load: [:directory, :note_type])

    {:ok, note: note, directory: directory, note_type: note_type}
  end

  describe "to_markdown/1" do
    test "converts note text to markdown string", %{note: note} do
      markdown = Exporter.to_markdown(note)

      assert is_binary(markdown)
      assert markdown == "# System Architecture\n\nThis is the architecture documentation."
    end

    test "handles nil text gracefully", %{note: note} do
      note_with_nil_text = %{note | text: nil}

      markdown = Exporter.to_markdown(note_with_nil_text)

      assert markdown == ""
    end

    test "handles empty text", %{note: note} do
      note_with_empty_text = %{note | text: ""}

      markdown = Exporter.to_markdown(note_with_empty_text)

      assert markdown == ""
    end
  end

  describe "to_json_metadata/1" do
    test "includes all required fields in new format", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert metadata["_schema_version"] == "1.0"
      assert metadata["_id"] == note.id
      assert metadata["_note"]
      assert metadata["name"] == "Architecture Notes"
      assert metadata["tags"]
      assert metadata["data"]
    end

    test "includes tags as array", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert metadata["tags"] == ["architecture", "design"]
    end

    test "includes custom data", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert metadata["data"] == %{"status" => "draft", "version" => "1.0"}
    end

    test "handles nil tags", %{note: note} do
      note_with_nil_tags = %{note | tags: nil}

      metadata = Exporter.to_json_metadata(note_with_nil_tags)

      assert metadata["tags"] == []
    end

    test "handles nil data", %{note: note} do
      note_with_nil_data = %{note | data: nil}

      metadata = Exporter.to_json_metadata(note_with_nil_data)

      assert metadata["data"] == %{}
    end
  end

  describe "export_note/1" do
    test "returns tuple with markdown and json content", %{note: note} do
      assert {:ok, {markdown, json_string}} = Exporter.export_note(note)

      assert is_binary(markdown)
      assert is_binary(json_string)

      assert markdown =~ "System Architecture"

      metadata = Jason.decode!(json_string)
      assert metadata["_id"] == note.id
      assert metadata["name"] == "Architecture Notes"
    end

    test "json content is valid and formatted", %{note: note} do
      assert {:ok, {_markdown, json_string}} = Exporter.export_note(note)

      assert {:ok, decoded} = Jason.decode(json_string)
      assert is_map(decoded)
    end

    test "handles note with minimal data" do
      directory = generate(directory(path: "minimal"))
      note_type = generate(note_type(name: "Minimal"))

      {:ok, minimal_note} =
        Xeno.Content.Note.create(%{
          name: "Minimal",
          directory_id: directory.id,
          note_type_id: note_type.id
        })

      minimal_note = Ash.get!(Xeno.Content.Note, minimal_note.id)

      assert {:ok, {markdown, json_string}} = Exporter.export_note(minimal_note)
      assert is_binary(markdown)
      assert is_binary(json_string)
    end
  end

  describe "to_json_metadata/1 - NEW FORMAT requirements" do
    test "uses _id instead of id", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert Map.has_key?(metadata, "_id")
      assert metadata["_id"] == note.id
      refute Map.has_key?(metadata, "id")
    end

    test "includes _schema_version field", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert metadata["_schema_version"] == "1.0"
    end

    test "includes _note field with system message", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert Map.has_key?(metadata, "_note")
      assert is_binary(metadata["_note"])
      assert String.contains?(metadata["_note"], "system-generated")
    end

    test "excludes version field from JSON", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      refute Map.has_key?(metadata, "version")
    end

    test "excludes note_type_id from JSON", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      refute Map.has_key?(metadata, "note_type_id")
    end

    test "excludes inserted_at from JSON", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      refute Map.has_key?(metadata, "inserted_at")
    end

    test "excludes updated_at from JSON", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      refute Map.has_key?(metadata, "updated_at")
    end

    test "keeps only user-editable fields plus system _fields", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      keys = Map.keys(metadata)
      assert length(keys) == 6

      assert "_schema_version" in keys
      assert "_id" in keys
      assert "_note" in keys
      assert "name" in keys
      assert "tags" in keys
      assert "data" in keys
    end

    test "preserves name, tags, and data fields", %{note: note} do
      metadata = Exporter.to_json_metadata(note)

      assert metadata["name"] == "Architecture Notes"
      assert metadata["tags"] == ["architecture", "design"]
      assert metadata["data"] == %{"status" => "draft", "version" => "1.0"}
    end
  end
end
