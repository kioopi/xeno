defmodule Xeno.Files.Directory.NameGenerationTest do
  use Xeno.DataCase, async: true
  use ExUnitProperties

  alias Xeno.Files.Directory

  describe "auto-generation of name/filename" do
    test "generates filename from name with simple text" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "My Documents"})
               |> Ash.create()

      assert directory.name == "My Documents"
      assert directory.filename == "my_documents"
    end

    test "generates filename from name with special characters" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Work/Projects"})
               |> Ash.create()

      assert directory.name == "Work/Projects"
      assert directory.filename == "work_projects"
    end

    test "generates filename from name with multiple spaces" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Multiple   Spaces"})
               |> Ash.create()

      assert directory.name == "Multiple   Spaces"
      assert directory.filename == "multiple_spaces"
    end

    test "generates filename from name with mixed special chars" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{name: "Personal Notes!"})
               |> Ash.create()

      assert directory.name == "Personal Notes!"
      assert directory.filename == "personal_notes"
    end

    test "generates name from filename with underscores" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "my_documents"})
               |> Ash.create()

      assert directory.filename == "my_documents"
      assert directory.name == "My Documents"
    end

    test "generates name from filename with multiple underscores" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "personal_notes"})
               |> Ash.create()

      assert directory.filename == "personal_notes"
      assert directory.name == "Personal Notes"
    end

    test "generates name from filename with single word" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{filename: "documents"})
               |> Ash.create()

      assert directory.filename == "documents"
      assert directory.name == "Documents"
    end

    test "keeps both values when both are provided" do
      assert {:ok, directory} =
               Directory
               |> Ash.Changeset.for_create(:create, %{
                 name: "Custom Name",
                 filename: "custom_filename"
               })
               |> Ash.create()

      assert directory.name == "Custom Name"
      assert directory.filename == "custom_filename"
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
