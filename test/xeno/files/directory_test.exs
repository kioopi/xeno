defmodule Xeno.Files.DirectoryTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  import Xeno.Generators
  import Ash.Generator, only: [action_input: 2]
  alias Xeno.Files.Directory

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
end
