defmodule Xeno.Files.Directory.Depth do
  use Ash.Resource.Calculation
  require Ash.Query

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &length(&1.path_ltree))
  end

  @impl true
  def expression(_opts, _context) do
    expr(fragment("nlevel(?)", path_ltree))
  end
end
