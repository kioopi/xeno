defmodule Xeno.Files.Directory.NameGenerationTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files.Directory

  describe "auto-generation of name/filename" do
    test "generates filename from name with simple text" do
      assert {:ok, directory} =
               Directory.create("my_documents")

      assert directory.name == "My Documents"
      assert directory.filename == "my_documents"
    end

    test "generates filename from name with special characters" do
      assert {:ok, directory} =
               Directory.create("some/path", %{name: "Dif Name"})

      assert directory.name == "Dif Name"
      assert directory.filename == "path"
    end

    test "fails validation when neither name nor filename provided" do
      assert {:error, changeset} =
               Directory
               |> Ash.Changeset.for_create(:create, %{})
               |> Ash.create()

      assert changeset.errors != []
    end
  end
end
