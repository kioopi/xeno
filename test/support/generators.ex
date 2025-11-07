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
      %Xeno.Files.Directory{name: "Notes", path: "notes", filename: "notes"}

      iex> generate(directory(name: "Custom", path: "some/path"))
      %Xeno.Files.Directory{name: "Custom", path: "some/path", filename: "path"}
  """
  def directory(opts \\ []) do
    example_dirs = ~w[Documents Projects Notes Archive Personal Work Ideas Research]

    path_generator =
      Enum.map(example_dirs, &String.downcase/1)
      |> StreamData.member_of()
      |> StreamData.list_of(length: 1..4)
      |> StreamData.nonempty()

    changeset_generator(
      Directory,
      :create,
      uses: [
        params: params_generator(path_generator)
      ],
      defaults: fn %{params: params} ->
        [
          name: params.name,
          path: params.path
        ]
      end,
      overrides: opts
    )
  end

  def params_generator(genarator) do
    StreamData.repeatedly(fn ->
      path =
        genarator
        |> Enum.take(1)
        |> List.first()

      %{
        path: Path.join(path),
        name: List.last(path) |> String.capitalize()
      }
    end)
  end
end
