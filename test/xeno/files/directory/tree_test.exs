defmodule Xeno.Files.Directory.TreeTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files.Directory

  require Ash.Query

  describe "Directory Tree" do
    test "creates a nested directory structure" do
      # Create nested directories
      create!("dir1")
      create!("dir2")
      create!("dir1/dir11")

      tree = Directory.Tree.build(Directory, & &1.filename)

      assert tree == [
               {"dir1", [{"dir11", []}]},
               {"dir2", []}
             ]
    end

    test "nested to differnt levels" do
      # Create nested directories
      create!("dir1")
      create!("dir2")
      create!("dir1/dir11")
      create!("dir1/dir11/dir111")
      create!("dir2/dir21")
      create!("dir3")
      create!("dir2/dir22")
      create!("dir2/dir22/dir221")
      create!("dir3/dir31")
      create!("dir3/dir31/dir311")
      create!("dir3/dir31/dir311/dir3111")
      create!("dir3/dir31/dir311/dir3112")
      create!("dir4")

      tree = Directory.Tree.build(Directory, & &1.filename)

      assert tree == [
               {"dir1", [{"dir11", [{"dir111", []}]}]},
               {"dir2", [{"dir21", []}, {"dir22", [{"dir221", []}]}]},
               {"dir3", [{"dir31", [{"dir311", [{"dir3111", []}, {"dir3112", []}]}]}]},
               {"dir4", []}
             ]
    end

    def create!(path) do
      Directory.create!(path, load: [:depth, :parent])
    end
  end
end
