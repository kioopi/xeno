defmodule Xeno.Generators do
  @moduledoc """
  Generators for creating test data for Notes resources using Ash.Generator.
  """

  use Ash.Generator

  alias Xeno.Files.Directory

  @doc """
  Generates a Directory resource with random or specified attributes.

  ## Options
  - `:name` - Override the generated name
  - `:filename` - Override the generated filename

  ## Examples

      iex> generate(directory())
      %Xeno.Files.Directory{name: "My Directory 1", filename: "my_directory_1"}

      iex> generate(directory(name: "Custom", filename: "custom"))
      %Xeno.Files.Directory{name: "Custom", filename: "custom"}
  """
  def directory(opts \\ []) do
    changeset_generator(
      Directory,
      :create,
      defaults: directory_defaults(opts),
      overrides: opts
    )
  end

  defp directory_defaults(opts) do
    example_dirs = ~w[Documents Projects Notes Archive Personal Work Ideas Research]

    case Keyword.has_key?(opts, :filename) do
      true -> []
      false -> [name: StreamData.member_of(example_dirs)]
    end
  end
end
