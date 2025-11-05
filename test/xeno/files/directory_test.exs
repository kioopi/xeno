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

  describe "get_or_create" do
    test "creates a directory" do
      assert {:ok, directory} = Directory.get_or_create("my_documents")

      assert directory.name == "My Documents"
      assert directory.filename == "my_documents"
      assert is_binary(directory.id)
    end

    test "returns existing" do
      dir = generate(directory())

      assert {:ok, directory} = Directory.get_or_create(dir.filename)

      assert dir.id == directory.id
    end

    test "creates with parent" do
      parent = generate(directory())

      assert {:ok, directory} = Directory.get_or_create("new_dir", parent.id)

      assert parent.id == directory.parent_id
      assert directory.name == "New Dir"
    end

    test "returns existing with parent" do
      parent = generate(directory())

      assert {:ok, child} =
               Directory
               |> Ash.Changeset.for_create(:create_child, %{
                 filename: "dir",
                 parent_id: parent.id
               })
               |> Ash.create()

      assert {:ok, new} = Directory.get_or_create("dir", parent.id)

      assert child.id == new.id
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

  test "test fixture directories exist" do
    assert File.exists?(Xeno.notes_dir("fixtures/grandparent"))
  end

  describe "create_from_filesystem action" do
    test "creates directories from filesystem path" do
      path = Xeno.notes_dir("fixtures")

      assert {:ok, directories} = Directory.create_from_filesystem(path)

      assert is_list(directories)
      assert length(directories) > 0

      # Verify all directories are Directory structs
      assert Enum.all?(directories, &match?(%Directory{}, &1))
    end

    test "creates nested directory hierarchy" do
      path = Xeno.notes_dir("fixtures/grandparent")

      assert {:ok, directories} = Directory.create_from_filesystem(path)

      # Since we're starting from grandparent, we get: parent, child
      assert length(directories) == 2

      # Verify parent-child relationships exist
      filenames = Enum.map(directories, & &1.filename)
      assert "parent" in filenames
      assert "child" in filenames
    end

    test "is idempotent - running twice doesn't create duplicates" do
      path = Xeno.notes_dir("fixtures/grandparent")

      assert {:ok, first_run} = Directory.create_from_filesystem(path)
      first_count = length(first_run)

      assert {:ok, second_run} = Directory.create_from_filesystem(path)
      assert first_count == length(second_run)

      # Should return same directories
      assert first_run == second_run

      # Check total count in database hasn't increased
      assert {:ok, all_dirs} = Ash.read(Directory)
      assert length(all_dirs) == first_count
    end

    test "sets parent_id correctly for nested directories" do
      path = Xeno.notes_dir("fixtures/grandparent")

      assert {:ok, directories} = Directory.create_from_filesystem(path)

      # Find parent and child
      parent = Enum.find(directories, &(&1.filename == "parent"))
      child = Enum.find(directories, &(&1.filename == "child"))

      assert parent != nil
      assert child != nil

      # Child should have parent as parent_id
      assert child.parent_id == parent.id
    end

    test "handles empty directories" do
      # Create a temporary empty directory for testing
      empty_path = Xeno.notes_dir("test_empty_dir")
      File.mkdir_p!(empty_path)

      on_exit(fn ->
        File.rm_rf!(empty_path)
      end)

      assert {:ok, directories} = Directory.create_from_filesystem(empty_path)

      # Should return empty list for directory with no subdirectories
      assert directories == []
    end

    test "returns error for non-existent path" do
      path = "/non/existent/path"

      assert {:error, error} = Directory.create_from_filesystem(path)

      # Verify it's an appropriate error
      assert error != nil
    end

    test "processes multi-level hierarchy correctly" do
      path = Xeno.notes_dir("fixtures")

      assert {:ok, directories} = Directory.create_from_filesystem(path)

      # Should have: grandparent, parent, child
      filenames = Enum.map(directories, & &1.filename)
      assert "grandparent" in filenames
      assert "parent" in filenames
      assert "child" in filenames
      assert "theme" in filenames

      # Verify the chain: grandparent -> parent -> child
      grandparent = Enum.find(directories, &(&1.filename == "grandparent"))
      parent = Enum.find(directories, &(&1.filename == "parent"))
      child = Enum.find(directories, &(&1.filename == "child"))

      assert parent.parent_id == grandparent.id
      assert child.parent_id == parent.id
    end
  end
end
