defmodule Xeno.Files.Directory.NoteTreeTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files.NoteTree
  alias Xeno.Files.Directory

  require Ash.Query

  describe "build/1" do
    test "contains notes" do
      root_dir = create!("root")
      child1 = create!("root/child1")

      %{id: note_id} = generate(note(directory_id: child1.id))

      tree = NoteTree.build()

      assert [{root, [{child, []}]}] = tree

      assert root_dir.id == root.id
      [child_note] = child.notes

      assert child_note.id == note_id
    end

    test "does not contain dirs without notes" do
      create!("root")

      tree = NoteTree.build()

      assert [] = tree
    end

    test "contains dirs with notes" do
      %{id: dir_id} = create!("root")
      %{id: note_id} = generate(note(directory_id: dir_id))

      tree = NoteTree.build()

      assert [{dir, []}] = tree

      [note] = dir.notes

      assert dir.id == dir_id
      assert note.id == note_id
    end

    test "doen not contain dirs that have children, when no notes" do
      create!("root")
      create!("root/child")

      tree = NoteTree.build()

      assert [] = tree
    end

    test "does contain dirs that have children that contain notes, but not decendants without notes" do
      create!("root")
      middle = create!("root/child")
      create!("root/child/leaf")

      %{id: note_id} = generate(note(directory_id: middle.id))

      assert [{_root, [{middle, []}]}] = NoteTree.build()

      [note] = middle.notes

      assert note.id == note_id
    end

    test "does contain dirs that have descendants with notes" do
      create!("root")
      create!("root/child")
      %{id: dir_id} = create!("root/child/leaf")

      %{id: note_id} = generate(note(directory_id: dir_id))

      assert [{_root, [{_child, [{leaf, []}]}]}] = NoteTree.build()

      [note] = leaf.notes

      assert note.id == note_id
    end

    defp create!(path) do
      Directory.create!(path)
    end
  end
end
