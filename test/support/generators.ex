defmodule Xeno.Generators do
  @moduledoc """
  Generators for creating test data for Notes resources using Ash.Generator.
  """

  use Ash.Generator

  alias Xeno.Notes.Directory

  @doc """
  Generates a Directory resource with random or specified attributes.

  ## Options
  - `:name` - Override the generated name
  - `:filename` - Override the generated filename
  - `:parent_id` - Set a parent directory ID

  ## Examples

      iex> generate(directory())
      %Xeno.Notes.Directory{name: "My Directory 1", filename: "my_directory_1"}

      iex> generate(directory(name: "Custom", filename: "custom"))
      %Xeno.Notes.Directory{name: "Custom", filename: "custom"}
  """
  def directory(opts \\ []) do
    example_dirs = [
      "Documents",
      "Projects",
      "Notes",
      "Archive",
      "Personal",
      "Work",
      "Ideas",
      "Research"
    ]

    changeset_generator(
      Directory,
      :create,
      defaults: [
        name: StreamData.member_of(example_dirs)
      ],
      overrides: opts
    )
  end

  @doc """
  Generates a Directory with a unique sequential name.

  Useful when you need multiple directories with unique names.

  ## Examples

      iex> generate(directory_with_sequence(1))
      %Xeno.Notes.Directory{name: "Directory 1", filename: "directory_1"}
  """
  def directory_with_sequence(n) when is_integer(n) do
    directory(
      name: "Directory #{n}",
      filename: "directory_#{n}"
    )
  end
end
