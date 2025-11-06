defmodule Xeno.FilesTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files
  alias Xeno.Files.Directory

  describe "create_direcories_from_filesystme" do
    test "creates directories from filesystem path" do
      path = Xeno.notes_dir("fixtures")

      assert {:ok, directories} = Files.create_directories_from_filesystem(path)

      assert is_list(directories)
      assert length(directories) > 0

      # Verify all directories are Directory structs
      assert Enum.all?(directories, &match?(%Directory{}, &1))
    end
  end
end
