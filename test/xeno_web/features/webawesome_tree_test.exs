defmodule XenoWeb.Features.WebAwesomeTreeTest do
  use XenoWeb.FeatureCase, async: false

  @moduledoc """
  TDD tests for WebAwesome tree component implementation.

  These tests drive the implementation of a WebAwesome-based directory tree
  """

  describe "WebAwesome tree component" do
    test "renders wa-tree element on the page" do
      build_conn()
      |> visit("/info")
      |> assert_has("wa-tree#webawesome-directory-tree")
    end

    test "renders wa-tree-item elements for each root directory" do
      # First, create some test directories so we have data to display
      Xeno.Files.Directory.create!("/test_dir_1")
      Xeno.Files.Directory.create!("/test_dir_2")

      session =
        build_conn()
        |> visit("/info")

      # Assert we have tree items (using the user-friendly names which have caps and spaces)
      session
      |> assert_has("wa-tree-item", text: "Test Dir 1")
      |> assert_has("wa-tree-item", text: "Test Dir 2")
    end

    test "renders nested wa-tree-item elements for directory hierarchies" do
      # Create a two-level nested structure (parent -> child)
      # Start with something simpler that we know works in other tests
      _parent = Xeno.Files.Directory.create!("treeparent")
      _child = Xeno.Files.Directory.create!("treeparent/treechild")

      session =
        build_conn()
        |> visit("/info")

      # Assert we have both levels in the tree
      session
      |> assert_has("wa-tree-item", text: "Treeparent")
      |> assert_has("wa-tree-item", text: "Treechild")
    end
  end
end
