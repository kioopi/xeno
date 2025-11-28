defmodule XenoWeb.Features.SmokeTest do
  use XenoWeb.FeatureCase, async: false

  @moduledoc """
  Smoke test to verify PhoenixTest and browser testing infrastructure is working.
  """

  test "can load the home page" do
    build_conn()
    |> visit("/")
    |> assert_has("h1", text: "Welcome to Xeno")
  end
end
