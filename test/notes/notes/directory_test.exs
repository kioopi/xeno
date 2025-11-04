defmodule Notes.Notes.DirectoryTest do
  use Notes.DataCase, async: true
  use ExUnitProperties

  import Notes.Generators
  import Ash.Generator, only: [action_input: 2]

  alias Notes.Notes.Directory

  describe "create action" do
    test "creates a directory with valid attributes" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{
                 name: "My Documents",
                 filename: "my_documents"
               })
               |> Ash.create()

      assert directory.name == "My Documents"
      assert directory.filename == "my_documents"
      assert is_binary(directory.id)
    end

    test "auto-generates name when only filename provided" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "documents"})
               |> Ash.create()

      assert directory.name == "Documents"
      assert directory.filename == "documents"
    end

    test "auto-generates filename when only name provided" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Documents"})
               |> Ash.create()

      assert directory.name == "Documents"
      assert directory.filename == "documents"
    end

    property "creates directories with generated data" do
      check all(input <- action_input(Directory, :create)) do
        assert {:ok, directory} =
                 Directory
                 |> Ash.Changeset.for_create(:create, input)
                 |> Ash.create()

        assert is_binary(directory.name)
        assert is_binary(directory.filename)
        assert is_binary(directory.id)
      end
    end
  end

  describe "read action" do
    test "can generate" do
      dir = generate(directory())

      assert %Directory{} = dir
    end

    test "can read created directory" do
      created = generate(directory(name: "Test"))

      assert {:ok, [found]} = Ash.read(Directory)
      assert found.id == created.id
      assert found.name == created.name
    end

    test "returns empty list when no directories exist" do
      assert {:ok, []} = Ash.read(Directory)
    end
  end

  describe "parent relationship" do
    test "can create directory with parent" do
      parent = generate(directory(name: "Parent"))

      assert {:ok, child} =
               Directory
               |> Ash.Changeset.for_create(:create_child, %{
                 name: "Child",
                 filename: "child",
                 parent_id: parent.id
               })
               |> Ash.create()

      assert child.parent_id == parent.id
    end

    test "can create directory without parent (root directory)" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Root",
                 filename: "root"
               })
               |> Ash.create()

      assert is_nil(directory.parent_id)
    end
  end

  describe "timestamps" do
    test "sets inserted_at and updated_at on creation" do
      {:ok, directory} =
        Directory
        |> Ash.Changeset.for_create(:create, %{name: "Test", filename: "test"})
        |> Ash.create()

      assert %DateTime{} = directory.inserted_at
      assert %DateTime{} = directory.updated_at
    end
  end

  describe "auto-generation of name/filename" do
    test "generates filename from name with simple text" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "My Documents"})
               |> Ash.create()

      assert directory.name == "My Documents"
      assert directory.filename == "my_documents"
    end

    test "generates filename from name with special characters" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Work/Projects"})
               |> Ash.create()

      assert directory.name == "Work/Projects"
      assert directory.filename == "work_projects"
    end

    test "generates filename from name with multiple spaces" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Multiple   Spaces"})
               |> Ash.create()

      assert directory.name == "Multiple   Spaces"
      assert directory.filename == "multiple_spaces"
    end

    test "generates filename from name with mixed special chars" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Personal Notes!"})
               |> Ash.create()

      assert directory.name == "Personal Notes!"
      assert directory.filename == "personal_notes"
    end

    test "generates name from filename with underscores" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "my_documents"})
               |> Ash.create()

      assert directory.filename == "my_documents"
      assert directory.name == "My Documents"
    end

    test "generates name from filename with multiple underscores" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "personal_notes"})
               |> Ash.create()

      assert directory.filename == "personal_notes"
      assert directory.name == "Personal Notes"
    end

    test "generates name from filename with single word" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "documents"})
               |> Ash.create()

      assert directory.filename == "documents"
      assert directory.name == "Documents"
    end

    test "keeps both values when both are provided" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Custom Name",
                 filename: "custom_filename"
               })
               |> Ash.create()

      assert directory.name == "Custom Name"
      assert directory.filename == "custom_filename"
    end

    test "fails validation when neither name nor filename provided" do
      assert {:error, changeset} =
               Directory
               |> Ash.Changeset.for_create(:create, %{})
               |> Ash.create()

      assert changeset.errors != []
    end
  end
end
