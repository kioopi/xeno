defmodule XenoWeb.Features.NoteLifecycleTest do
  use XenoWeb.FeatureCase, async: false
  import Xeno.Generators

  @moduledoc """
  End-to-end feature tests verifying component library integration.

  These tests focus on verifying that the refactored templates using
  the new component library work correctly in real user scenarios.
  """

  describe "component library integration on note show page" do
    test "page uses wa-button component with auto-generated ID" do
      note = generate(note())

      build_conn()
      |> visit("/notes/#{note.id}")
      |> assert_has("wa-button#edit-btn", text: "Edit")
    end

    test "page uses proper heading hierarchy" do
      note = generate(note(text: "hello"))

      build_conn()
      |> visit("/notes/#{note.id}")
      |> assert_has("h1", text: note.name)
      |> assert_has("h2", text: "Content")
    end

    test "page displays tags with wa-tag component" do
      note = generate(note(tags: ["elixir", "phoenix"]))

      build_conn()
      |> visit("/notes/#{note.id}")
      |> assert_has("wa-tag", text: "elixir")
      |> assert_has("wa-tag", text: "phoenix")
    end
  end

  describe "component library integration on note edit page" do
    test "page uses container and form components" do
      note = generate(note())

      session = build_conn() |> visit("/notes/#{note.id}/edit")

      # Verify form exists
      assert_has(session, "form")

      # Verify buttons exist
      assert_has(session, "button", text: "Save Changes")
      assert_has(session, "button", text: "Cancel")
    end

    test "page has proper heading" do
      note = generate(note())

      build_conn()
      |> visit("/notes/#{note.id}/edit")
      |> assert_has("h1", text: "Edit Note")
    end
  end

  describe "UI consistency across pages" do
    test "sync page has proper heading" do
      build_conn()
      |> visit("/sync")
      |> assert_has("h1", text: "Editor Integration")
    end

    test "sync page uses component library" do
      build_conn()
      |> visit("/sync")
      |> assert_has("wa-button")
      |> assert_has("wa-card")
    end
  end

  describe "basic user interactions" do
    test "edit page is accessible and has correct structure" do
      note = generate(note())

      build_conn()
      |> visit("/notes/#{note.id}/edit")
      |> assert_path("/notes/#{note.id}/edit")
      |> assert_has("h1", text: "Edit Note")
      |> assert_has("form")
    end

    test "note show page has edit button with correct ID" do
      note = generate(note())

      build_conn()
      |> visit("/notes/#{note.id}")
      |> assert_has("wa-button#edit-btn", text: "Edit")
    end
  end
end
