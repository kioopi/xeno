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
        defaults: defaults_generator(path_generator)
      ],
      defaults: & &1.defaults,
      overrides: overrides(opts)
    )
  end

  defp defaults_generator(genarator) do
    StreamData.repeatedly(fn ->
      path =
        genarator
        |> Enum.take(1)
        |> List.first()

      [
        path: Path.join(path),
        name: List.last(path) |> String.capitalize()
      ]
    end)
  end

  defp overrides(opts) do
    set_name(opts, opts[:name], opts[:path])
  end

  defp set_name(opts, _, nil), do: opts

  defp set_name(opts, nil, path) do
    name =
      path
      |> String.split("/")
      |> List.last()
      |> String.capitalize()

    Keyword.put(opts, :name, name)
  end

  defp set_name(opts, _, _), do: opts
end
