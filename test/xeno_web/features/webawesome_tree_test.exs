defmodule XenoWeb.Features.WebAwesomeTreeTest do
  use XenoWeb.FeatureCase, async: false

  @moduledoc """
  TDD tests for WebAwesome tree component implementation.

  These tests drive the implementation of a WebAwesome-based directory tree
  that will be displayed alongside the existing HTML <details> tree for
  comparison.
  """

  describe "WebAwesome tree component" do
    test "renders wa-tree element on the page" do
      build_conn()
      |> visit("/")
      |> assert_has("wa-tree#webawesome-directory-tree")
    end

    test "renders wa-tree-item elements for each root directory" do
      # First, create some test directories so we have data to display
      Xeno.Files.Directory.create!("/test_dir_1")
      Xeno.Files.Directory.create!("/test_dir_2")

      session =
        build_conn()
        |> visit("/")

      # Assert we have tree items (using the user-friendly names which have caps and spaces)
      session
      |> assert_has("wa-tree-item", text: "Test Dir 1")
      |> assert_has("wa-tree-item", text: "Test Dir 2")
    end
  end
end
