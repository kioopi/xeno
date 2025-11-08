defmodule Xeno.Files.Directory.Filename do
  use Ash.Resource.Calculation
  require Ash.Query

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &List.last(&1.path_ltree))
  end

  @impl true
  def expression(_opts, _context) do
    expr(fragment("subpath(?, -1)", path_ltree))
  end
end
