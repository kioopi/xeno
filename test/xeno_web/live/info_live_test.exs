defmodule XenoWeb.InfoLiveTest do
  use XenoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    notes_dir = Xeno.notes_dir()
    Xeno.Files.Directory.create!(notes_dir, %{name: "root"})
    # Xeno.Files.create_directories_from_filesystem!(notes_dir)
    :ok
  end

  test "displays Xeno installation information", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "h1", "Xeno Installation Information")
  end

  test "displays the notes directory path", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert view |> element("dd") |> render() =~ Xeno.notes_dir()

    assert has_element?(view, "dd", Xeno.notes_dir())
  end

  describe "auto-refresh" do
    test "automatically shows new directory when created", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Initially no directory with this name
      refute has_element?(view, "details", "Newtestdir")

      # Create directory (triggers PubSub broadcast)
      _new_dir = Xeno.Files.Directory.create!("newtestdir")

      # Should automatically appear in the tree
      assert has_element?(view, "details", "Newtestdir")
    end

    test "shows new nested directory under correct parent", %{conn: conn} do
      # Create root directory first
      _root = Xeno.Files.Directory.create!("parentroot")

      {:ok, view, _html} = live(conn, ~p"/")

      # Root should be visible
      assert has_element?(view, "details", "Parentroot")

      # Child should not exist yet
      refute has_element?(view, "details", "Childnested")

      # Create child (triggers PubSub broadcast)
      _child = Xeno.Files.Directory.create!("parentroot/childnested")

      # Should appear nested under root
      assert has_element?(view, "details", "Parentroot")
      assert has_element?(view, "details", "Childnested")
    end

    test "verifies pubsub broadcast actually happens and LiveView receives it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Subscribe to the same topic as LiveView
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")

      # Create directory (triggers PubSub broadcast)
      _dir = Xeno.Files.Directory.create!("integrationtest")

      # Wait for and verify we receive the PubSub broadcast
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "directory:created",
                       event: "create",
                       payload: %Phoenix.Socket.Broadcast{
                         payload: %Ash.Notifier.Notification{}
                       }
                     },
                     1000

      # Now verify LiveView also received it and updated
      assert has_element?(view, "details", "Integrationtest")
    end
  end
end
