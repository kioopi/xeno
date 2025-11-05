defmodule Xeno.Files.Validations.PathExists do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    if opts[:arg] != nil && is_atom(opts[:arg]) do
      {:ok, opts}
    else
      {:error, "arg must be an atom!"}
    end
  end

  @impl true
  def supports(_opts), do: [Ash.ActionInput]

  @impl true
  def validate(input, opts, _context) do
    path = Ash.ActionInput.get_argument(input, opts[:arg])

    if File.exists?(path) and File.dir?(path) do
      :ok
    else
      {:error, "Path does not exist or is not a directory: #{path}"}
    end
  end
end
