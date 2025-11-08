defmodule Xeno.Files.Directory.Path do
  use Ash.Resource.Calculation
  require Ash.Query

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &Path.join(&1.path_ltree))
  end

  @impl true
  def expression(_opts, _context) do
    expr(fragment("replace(ltree2text(?), '.', '/')", path_ltree))
  end
end
