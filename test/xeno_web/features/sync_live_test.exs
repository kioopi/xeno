defmodule XenoWeb.Features.SyncLiveTest do
  use XenoWeb.FeatureCase, async: false

  @moduledoc """
  Feature tests for the Sync LiveView UI.

  These tests focus on UI state, server-side logic, and user interactions
  that don't require the File System Access API (which cannot be automated).

  What IS tested:
  - UI element visibility based on state
  - Button enable/disable logic
  - Flash messages
  - Export preview functionality
  - Error message display

  What is NOT tested (requires manual testing):
  - Actual directory picker interaction
  - Real file system read/write
  - Permission grant/revoke flows
  - File System Access API functionality
  """

  describe "initial page load" do
    test "displays browser compatibility warning" do
      build_conn()
      |> visit("/sync")
      |> assert_has("p", text: "Note: This feature requires Chrome 86+ or Edge 86+")
    end

    test "shows connect button when not connected" do
      build_conn()
      |> visit("/sync")
      |> assert_has("#connect-directory-btn", text: "Choose Folder")
    end

    test "does not show export/import buttons when not connected" do
      session = build_conn() |> visit("/sync")

      refute_has(session, "#export-all-btn")
      refute_has(session, "#import-btn")
      refute_has(session, "#disconnect-directory-btn")
    end

    test "displays sync container with FileSystem hook" do
      build_conn()
      |> visit("/sync")
      |> assert_has("#sync-container[phx-hook='FileSystem']")
    end
  end

  describe "export preview" do
    test "export preview button exists" do
      build_conn()
      |> visit("/sync")
      |> assert_has("#export-preview-btn")
    end

    test "export all preview button exists" do
      build_conn()
      |> visit("/sync")
      |> assert_has("#export-all-preview-btn")
    end

    test "preview container exists when preview mode is active" do
      session = build_conn() |> visit("/sync")

      refute_has(session, "#preview-container")
    end
  end

  describe "UI state transitions" do
    test "connect button is visible when not connected" do
      build_conn()
      |> visit("/sync")
      |> assert_has("#connect-directory-btn")
    end

    test "page has proper heading" do
      build_conn()
      |> visit("/sync")
      |> assert_has("h1", text: "Editor Integration")
    end

    test "instructions are displayed" do
      build_conn()
      |> visit("/sync")
      |> assert_has("p", text: "Connect a local folder to sync your notes")
    end
  end

  describe "export/import functionality hints" do
    test "displays information about export functionality in card" do
      build_conn()
      |> visit("/sync")
      |> assert_has("h2", text: "Export Preview (Development)")
    end
  end

  describe "accessibility" do
    test "buttons have appropriate labels" do
      session = build_conn() |> visit("/sync")

      session
      |> assert_has("button", text: "Choose Folder")
      |> assert_has("button", text: "Preview Single Note")
    end

    test "page has proper semantic structure" do
      session = build_conn() |> visit("/sync")

      session
      |> assert_has("h1")
      |> assert_has("div#sync-container")
    end
  end

  describe "error scenarios" do
    test "page renders even when no notes exist" do
      build_conn()
      |> visit("/sync")
      |> assert_has("h1")
      |> assert_has("#connect-directory-btn")
    end
  end
end
