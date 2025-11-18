defmodule XenoWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by browser-based feature tests.

  Such tests rely on `PhoenixTest` for browser automation and typically
  test user workflows through the browser.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import PhoenixTest

      alias Xeno.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      @endpoint XenoWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xeno.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Xeno.Repo, {:shared, self()})
    end

    :ok
  end
end
