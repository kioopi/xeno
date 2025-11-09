defmodule Xeno.Files.Directory.TreeTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files.Directory

  require Ash.Query

  describe "find_root_ancestor/1" do
    test "returns the root directory for a nested directory" do
      root = create!("root")
      child = create!("root/child")
      grandchild = create!("root/child/grandchild")

      assert Directory.Tree.find_root_ancestor(grandchild).id == root.id
      assert Directory.Tree.find_root_ancestor(child).id == root.id
      assert Directory.Tree.find_root_ancestor(root).id == root.id
    end

    test "returns the directory itself if it's already a root" do
      root = create!("root")

      assert Directory.Tree.find_root_ancestor(root).id == root.id
    end

    test "handles multiple independent root trees" do
      root1 = create!("root1")
      child1 = create!("root1/child1")

      root2 = create!("root2")
      child2 = create!("root2/child2")

      assert Directory.Tree.find_root_ancestor(child1).id == root1.id
      assert Directory.Tree.find_root_ancestor(child2).id == root2.id
    end
  end

  describe "build_branch/1" do
    test "builds tree for a single root directory and its descendants" do
      root = create!("root")
      child1 = create!("root/child1")
      _child2 = create!("root/child2")
      grandchild = create!("root/child1/grandchild")

      branch = Directory.Tree.build_branch(root.id)

      # Should be a single root tuple with nested children
      assert {root_dir, children} = branch
      assert root_dir.id == root.id
      assert length(children) == 2

      # Find child1 in children
      {_child1_dir, child1_children} = Enum.find(children, fn {d, _} -> d.id == child1.id end)
      assert length(child1_children) == 1

      {gc_dir, gc_children} = List.first(child1_children)
      assert gc_dir.id == grandchild.id
      assert gc_children == []
    end

    test "handles root with no children" do
      root = create!("lonely")

      assert {root_dir, []} = Directory.Tree.build_branch(root.id)
      assert root_dir.id == root.id
    end

    test "only builds branch for specified root, not other roots" do
      root1 = create!("root1")
      create!("root1/child1")

      _root2 = create!("root2")
      create!("root2/child2")

      branch = Directory.Tree.build_branch(root1.id)

      # Should only contain root1 and its descendants
      assert {root_dir, children} = branch
      assert root_dir.id == root1.id
      assert length(children) == 1

      {child_dir, _} = List.first(children)
      assert child_dir.filename == "child1"
    end
  end

  describe "update_tree/3" do
    test "replaces an existing branch in the tree with updated branch" do
      root1 = create!("root1")
      create!("root1/child1")

      root2 = create!("root2")
      create!("root2/child2")

      original_tree = Directory.Tree.build(Directory)

      # Rebuild root1's branch (simulating an update)
      new_branch = Directory.Tree.build_branch(root1.id)

      updated_tree = Directory.Tree.update_tree(original_tree, root1.id, new_branch)

      # Should have same number of roots
      assert length(updated_tree) == 2

      # Root1 branch should be the new one
      {updated_root1, _} = Enum.find(updated_tree, fn {d, _} -> d.id == root1.id end)
      assert updated_root1.id == root1.id

      # Root2 should still be in the tree
      {found_root2, _} = Enum.find(updated_tree, fn {d, _} -> d.id == root2.id end)
      assert found_root2.id == root2.id
    end

    test "appends new branch if root not found in tree" do
      root1 = create!("root1")

      tree = Directory.Tree.build(Directory)
      assert length(tree) == 1

      # Create a new root
      root2 = create!("root2")
      new_branch = Directory.Tree.build_branch(root2.id)

      updated_tree = Directory.Tree.update_tree(tree, root2.id, new_branch)

      # Should have 2 roots now
      assert length(updated_tree) == 2

      # Both roots should be in the tree
      assert Enum.any?(updated_tree, fn {d, _} -> d.id == root1.id end)
      assert Enum.any?(updated_tree, fn {d, _} -> d.id == root2.id end)
    end

    test "keeps unchanged branches intact" do
      root1 = create!("root1")
      root2 = create!("root2")

      original_tree = Directory.Tree.build(Directory)

      # Get the original root2 branch
      original_root2_branch = Enum.find(original_tree, fn {d, _} -> d.id == root2.id end)

      # Update root1's branch
      new_branch = Directory.Tree.build_branch(root1.id)
      updated_tree = Directory.Tree.update_tree(original_tree, root1.id, new_branch)

      # Root2 branch should be exactly the same object (not rebuilt)
      updated_root2_branch = Enum.find(updated_tree, fn {d, _} -> d.id == root2.id end)
      assert updated_root2_branch == original_root2_branch
    end
  end

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
