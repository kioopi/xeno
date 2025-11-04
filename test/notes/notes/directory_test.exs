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

    test "requires name attribute" do
      assert {:error, changeset} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "documents"})
               |> Ash.create()

      assert changeset.errors != []
    end

    test "requires filename attribute" do
      assert {:error, changeset} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Documents"})
               |> Ash.create()

      assert changeset.errors != []
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
      {:ok, created} =
        Directory
        |> Ash.Changeset.for_create(:create, %{name: "Test", filename: "test"})
        |> Ash.create()

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
      parent = generate(directory(name: "Parent", filename: "parent"))

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
end
