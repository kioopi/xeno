defmodule Xeno.Files.DirectoryTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  import Xeno.Generators
  import Ash.Generator, only: [action_input: 3]
  alias Xeno.Files.Directory

  require Ash.Query

  describe "create action" do
    property "creates directories with generated data" do
      gens = %{
        path:
          StreamData.string(:alphanumeric, min_length: 3)
          |> StreamData.list_of(length: 1..4)
          |> StreamData.map(&Path.join/1)
      }

      check all(input <- action_input(Directory, :create, gens)) do
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

  describe "generator" do
    test "generates directory" do
      dir = generate(directory())

      assert %Directory{} = dir
      assert List.last(dir.path_ltree) == dir.filename
      assert is_binary(dir.name)
    end

    test "takes name" do
      dir = generate(directory(name: "My Name"))
      assert "My Name" == dir.name
    end

    test "takes path" do
      dir = generate(directory(path: Path.join(~w"etc passwd")))

      assert "passwd" == dir.filename
    end
  end

  describe "create code_interface" do
    test "creates a Directory" do
      docs = Directory.create!("docs", load: [:filename])

      assert docs.path_ltree == [docs.filename]
      assert docs.path == docs.filename

      tut = Directory.create!("docs/tuts", %{name: "Tutorial"}, load: [:filename])

      assert tut.path_ltree == ["docs", tut.filename]
      assert tut.path == "docs/tuts"
      assert tut.name == "Tutorial"

      # path defines identity
      assert docs.id == Directory.get_or_create!(docs.filename).id

      assert "Tutorial" ==
               Directory.get_or_create!(tut.path, %{name: "Hello"}).name

      assert "Sci-enz" ==
               Directory.get_or_create!("science", %{name: "Sci-enz"}).name
    end

    test "creates a subdirectory" do
      dir = Directory.create!("docs/taxes")

      assert dir.path_ltree == ["docs", "taxes"]
      assert dir.path == "docs/taxes"
      assert dir.name == "Taxes"
    end

    test "name gets humanized" do
      dir = Directory.create!("docs/taxes/taxes_2005")

      assert dir.name == "Taxes 2005"
    end

    test "can deal with root dir" do
      dir = Directory.create!("/etc/passwd")

      assert dir.path == "etc/passwd"
    end
  end

  describe "get_or_create" do
    test "creates a directory" do
      directory = Directory.get_or_create!("my_documents")

      assert directory.name == "My Documents"
      assert directory.filename == "my_documents"
      assert is_binary(directory.id)
    end

    test "creates a subdirectory" do
      directory = Directory.get_or_create!("docs/taxes")

      assert directory.name == "Taxes"
      assert directory.filename == "taxes"
      assert is_binary(directory.id)
    end

    test "returns existing" do
      dir = Directory.create!("docs/taxes")

      assert directory = Directory.get_or_create!(dir.path)

      assert dir.id == directory.id
    end
  end

  describe "read action" do
    test "can generate a directory via the test generator" do
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

  describe "child relationship" do
    test "can load children" do
      parent = generate(directory(path: "etc"))

      generate(directory(path: "etc/iwd"))
      generate(directory(path: "etc/passwd"))

      dir = Ash.get!(Directory, parent.id, load: [children: :filename])

      children = Enum.map(dir.children, & &1.filename)

      assert children == ["passwd", "iwd"]
    end

    test "excludes grandchilden" do
      parent = generate(directory(path: "etc"))

      generate(directory(path: "etc/passwd"))
      generate(directory(path: "etc/iwd"))
      generate(directory(path: "etc/iwd/grandchild"))

      dir = Ash.get!(Directory, parent.id, load: [children: :filename])

      children = Enum.map(dir.children, & &1.filename)

      assert children == ["passwd", "iwd"]
    end

    test "descendants includes children and grandchilden" do
      parent = generate(directory(path: "etc"))

      generate(directory(path: "etc/passwd"))
      generate(directory(path: "etc/iwd"))
      generate(directory(path: "etc/iwd/grandchild"))

      dir = Ash.get!(Directory, parent.id, load: [descendants: [:parent, :filename]])

      child = find_by_filename(dir.descendants, "iwd")
      grandchild = find_by_filename(dir.descendants, "grandchild")

      assert child.parent.id == dir.id
      assert grandchild.parent.id == child.id
    end

    test "descendants does not include self" do
      parent = generate(directory(path: "etc"))

      generate(directory(path: "etc/passwd"))

      dir = Ash.get!(Directory, parent.id, load: [descendants: [:parent, :filename]])

      assert Enum.all?(dir.descendants, &(&1.id != parent.id))
    end
  end

  describe "parent relationship" do
    test "can load parent" do
      generate(directory(path: "etc"))

      child = generate(directory(path: "etc/iwd"))

      dir = Ash.get!(Directory, child.id, load: [parent: :filename])

      assert dir.parent.filename == "etc"
    end

    test "does not return grand parent" do
      generate(directory(path: "grand"))
      generate(directory(path: "grand/parent"))

      child = generate(directory(path: "grand/parent/child"))

      dir = Ash.get!(Directory, child.id, load: [parent: :filename])

      assert dir.parent.filename == "parent"
    end
  end

  describe "timestamps" do
    test "sets inserted_at and updated_at on creation" do
      {:ok, directory} =
        Directory
        |> Ash.Changeset.for_create(:create, %{path: "etc"})
        |> Ash.create()

      assert %DateTime{} = directory.inserted_at
      assert %DateTime{} = directory.updated_at
    end
  end

  describe "calculations" do
    test "filename" do
      %{id: id} = generate(directory(path: "etc/passwd"))

      dir = Ash.get!(Directory, id, load: [:filename])

      assert "passwd" == dir.filename
    end

    test "path" do
      %{id: id} = generate(directory(path: "etc/passwd"))

      dir = Ash.get!(Directory, id, load: [:path])

      assert "etc/passwd" == dir.path
    end
  end

  test "test fixture directories exist" do
    assert File.exists?(Xeno.notes_dir("fixtures/grandparent"))
  end

  describe "create_from_filesystem action" do
    test "creates directories from filesystem path" do
      path = Xeno.notes_dir("fixtures")

      assert directories = Directory.create_from_filesystem!(path)

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

    test "sets parent correctly for nested directories" do
      path = Xeno.notes_dir("fixtures/grandparent")

      assert {:ok, directories} = Directory.create_from_filesystem(path)

      # Find parent and child
      parent = find_by_filename(directories, "parent") |> Ash.load!(:children)
      child = find_by_filename(directories, "child") |> Ash.load!(:parent)

      assert parent != nil
      assert child != nil

      assert child.parent.id == parent.id

      assert Enum.any?(parent.children, &(&1.id == child.id))
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
      grandparent = find_by_filename(directories, "grandparent")
      parent = find_by_filename(directories, "parent") |> Ash.load!(parent: :filename)
      child = find_by_filename(directories, "child") |> Ash.load!(parent: :filename)

      assert parent.parent.id == grandparent.id
      assert child.parent.id == parent.id
    end
  end

  describe "playground" do
    test "see sql" do
      query =
        Ash.Query.for_read(Directory, :read)
        |> Ash.Query.filter(path == "etc.passwd")
        |> Ash.Query.load(:path)

      {:ok, data_layer_query} = Ash.data_layer_query(query)

      assert %Ecto.Query{} = data_layer_query.query

      {sql, args} = Xeno.Repo.to_sql(:all, data_layer_query.query)

      assert args == ["etc.passwd"]
      # this is the sql
      assert is_binary(sql)
    end
  end

  describe "querying" do
    test "by path equality" do
      generate(directory(path: "etc/passwd"))

      dir = Ash.Query.filter(Directory, path_ltree == "etc.passwd") |> Ash.read_one!()

      assert dir.filename == "passwd"
    end

    test "by path array" do
      generate(directory(path: "etc/passwd"))

      dir = Ash.Query.filter(Directory, path_ltree == ["etc", "passwd"]) |> Ash.read_one!()

      assert dir.filename == "passwd"
    end

    test "by path array in variable" do
      generate(directory(path: "etc/passwd"))
      p = ["etc", "passwd"]

      dir = Ash.Query.filter(Directory, path_ltree == ^p) |> Ash.read_one!()

      assert dir.filename == "passwd"
    end

    test "by_path action" do
      generate(directory(path: "etc/passwd"))

      dir = Ash.Query.for_read(Directory, :by_path, %{path: "etc/passwd"}) |> Ash.read_one!()

      assert dir.filename == "passwd"
    end

    test "descendants_of action" do
      parent = generate(directory(path: "etc"))

      generate(directory(path: "etc/passwd"))
      generate(directory(path: "etc/iwd"))

      dirs =
        Ash.Query.for_read(Directory, :descendants_of, %{parent: parent}, load: :parent)
        |> Ash.read!()

      iwd = find_by_filename(dirs, "iwd")
      passwd = find_by_filename(dirs, "passwd")

      assert iwd.parent.id == parent.id
      assert passwd.parent.id == parent.id
    end

    test "by_path code interface" do
      generate(directory(path: "etc/passwd"))

      dir = Directory.by_path!("etc/passwd")

      assert dir.filename == "passwd"
    end

    test "deals with root dir" do
      generate(directory(path: "etc/passwd"))

      dir = Directory.by_path!("/etc/passwd")

      assert dir.filename == "passwd"
    end
  end

  describe "move action" do
    test "new_path calculation" do
      generate(directory(path: "some/deep/directory/tree"))

      dir =
        Ash.Query.for_read(Directory, :by_path, %{path: "some/deep/directory/tree"})
        |> Directory.NewPath.add_calculation(~w"some very nice", ~w"some deep")
        |> Ash.read_one!()

      assert dir.calculations.new_path == ["some", "very", "nice", "directory", "tree"]
    end

    test "move action changes path" do
      dir = generate(directory(path: "some/deep/tree"))

      dir =
        dir
        |> Ash.Changeset.for_update(:move, %{path: "other/dir"}, load: [:filename, :path])
        |> Ash.update!()

      assert dir.path == "other/dir"
      assert dir.filename == "dir"
    end

    test "move action moves the descendants" do
      dir = generate(directory(path: "some/dir"))
      generate(directory(path: "some/dir/child"))
      generate(directory(path: "some/dir/child/grandson"))
      generate(directory(path: "some/dir/child/granddaughter"))

      dir =
        dir
        |> Ash.Changeset.for_update(:move, %{path: "some/very/new"},
          load: [:filename, :path, :descendants]
        )
        |> Ash.update!()

      assert Enum.map(dir.descendants, & &1.path) == [
               "some/very/new/child/grandson",
               "some/very/new/child/granddaughter",
               "some/very/new/child"
             ]
    end
  end

  defp find_by_filename(directories, name) do
    Enum.find(directories, &(&1.filename == name))
  end
end
