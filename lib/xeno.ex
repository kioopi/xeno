defmodule Xeno do
  @moduledoc """
  Xeno keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def notes_dir do
    Application.fetch_env!(:xeno, :notes_directory) |> Path.expand()
  end

  def notes_dir(path) do
    Path.join([notes_dir(), path])
  end
end
