defmodule Xeno.Files.Directory.UniqueFilenamesTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  import Xeno.Generators
  alias Xeno.Files.Directory

  describe "unique filename per parent" do
    test "prevents duplicate filenames in same parent directory" do
      generate(directory(path: "parent"))
      generate(directory(path: "parent/documents"))

      assert {:error, changeset} =
               Directory.create("parent/documents")

      # Verify error is about uniqueness constraint
      assert changeset.errors != []
    end

    test "prevents duplicate filenames at root level" do
      generate(directory(path: "docs"))

      # Attempt to create second root directory with same filename
      assert {:error, changeset} =
               Directory.create("docs")

      # Verify error is about uniqueness constraint
      assert changeset.errors != []
    end

    test "allows same filename in different parent directories" do
      p1 = generate(directory(path: "dir1"))
      p2 = generate(directory(path: "dir2"))

      # Create child with filename "notes" in first parent
      assert {:ok, child1} =
               Directory.create("dir1/notes", load: :parent)

      # Create child with same filename "notes" in second parent (should succeed)
      assert {:ok, child2} =
               Directory.create("dir2/notes", load: :parent)

      # Verify both children were created successfully
      assert child1.filename == "notes"
      assert child2.filename == "notes"
      assert child1.parent.id == p1.id
      assert child2.parent.id == p2.id
      assert child1.id != child2.id
    end
  end
end
