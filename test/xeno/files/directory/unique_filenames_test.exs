defmodule Xeno.Files.Directory.UniqueFilenamesTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  import Xeno.Generators
  alias Xeno.Files.Directory

  describe "unique filename per parent" do
    test "prevents duplicate filenames in same parent directory" do
      parent = generate(directory(name: "Parent"))

      # Create first child with filename "documents"
      assert {:ok, _child1} =
               Directory
               |> Ash.Changeset.for_create(:create_child, %{
                 name: "Documents",
                 filename: "documents",
                 parent_id: parent.id
               })
               |> Ash.create()

      # Attempt to create second child with same filename in same parent
      assert {:error, changeset} =
               Directory
               |> Ash.Changeset.for_create(:create_child, %{
                 name: "Documents 2",
                 filename: "documents",
                 parent_id: parent.id
               })
               |> Ash.create()

      # Verify error is about uniqueness constraint
      assert changeset.errors != []
    end

    test "prevents duplicate filenames at root level" do
      # Create first root directory with filename "docs"
      assert {:ok, _dir1} =
               Directory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Docs",
                 filename: "docs"
               })
               |> Ash.create()

      # Attempt to create second root directory with same filename
      assert {:error, changeset} =
               Directory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Docs 2",
                 filename: "docs"
               })
               |> Ash.create()

      # Verify error is about uniqueness constraint
      assert changeset.errors != []
    end

    test "allows same filename in different parent directories" do
      parent1 = generate(directory(name: "Parent 1"))
      parent2 = generate(directory(name: "Parent 2"))

      # Create child with filename "notes" in first parent
      assert {:ok, child1} =
               Directory
               |> Ash.Changeset.for_create(:create_child, %{
                 name: "Notes",
                 filename: "notes",
                 parent_id: parent1.id
               })
               |> Ash.create()

      # Create child with same filename "notes" in second parent (should succeed)
      assert {:ok, child2} =
               Directory
               |> Ash.Changeset.for_create(:create_child, %{
                 name: "Notes",
                 filename: "notes",
                 parent_id: parent2.id
               })
               |> Ash.create()

      # Verify both children were created successfully
      assert child1.filename == "notes"
      assert child2.filename == "notes"
      assert child1.parent_id == parent1.id
      assert child2.parent_id == parent2.id
      assert child1.id != child2.id
    end
  end
end
