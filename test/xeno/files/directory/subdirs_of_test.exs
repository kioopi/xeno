defmodule Xeno.Files.Directory.SubdirsOfTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files.Directory

  describe "subdirs_of" do
    test "returns array of paths to directories" do
      path = Xeno.notes_dir("fixtures")

      dirs = Directory.SubdirsOf.subdirs_of(path)

      # Returns subdirs breadth first and sorted by ascending depth
      # This makes it easy to recursively create directories in order
      assert [
               "grandparent",
               "theme",
               "grandparent/parent",
               "theme/subtheme",
               "grandparent/parent/child"
             ] == dirs
    end
  end
end
