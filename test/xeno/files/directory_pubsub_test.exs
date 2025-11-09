defmodule Xeno.Files.DirectoryPubSubTest do
  use Xeno.DataCase, async: true

  alias Xeno.Files.Directory

  # Helper to generate unique directory names to avoid cross-test pollution
  defp unique_name do
    "test_#{System.unique_integer([:positive])}"
  end

  describe "pubsub notifications" do
    test "broadcasts message on directory:created topic when directory is created" do
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")

      directory = Directory.create!(unique_name())
      dir_id = directory.id

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "directory:created",
        event: "create",
        payload: %Phoenix.Socket.Broadcast{
          payload: %Ash.Notifier.Notification{
            data: %{id: ^dir_id}
          }
        }
      }
    end

    test "broadcasts message on directory:updated topic when directory is updated" do
      directory = Directory.create!(unique_name())

      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")

      updated = Directory.update!(directory, %{name: "Updated Name"})
      updated_id = updated.id

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "directory:updated",
        event: "update",
        payload: %Phoenix.Socket.Broadcast{
          payload: %Ash.Notifier.Notification{
            data: %{id: ^updated_id}
          }
        }
      }
    end

    test "broadcasts message on directory:moved topic when directory is moved" do
      parent1 = Directory.create!(unique_name())
      parent2 = Directory.create!(unique_name())
      child = Directory.create!("#{parent1.filename}/child")

      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")

      moved = Directory.move!(child, %{path: "#{parent2.filename}/child"})
      moved_id = moved.id

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "directory:moved",
        event: "move",
        payload: %Phoenix.Socket.Broadcast{
          payload: %Ash.Notifier.Notification{
            data: %{id: ^moved_id}
          }
        }
      }
    end

    test "broadcasts message on directory:destroyed topic when directory is destroyed" do
      directory = Directory.create!(unique_name())
      dir_id = directory.id

      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:destroyed")

      :ok = Directory.destroy!(directory)

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "directory:destroyed",
        event: "destroy",
        payload: %Phoenix.Socket.Broadcast{
          payload: %Ash.Notifier.Notification{
            data: %{id: ^dir_id}
          }
        }
      }
    end

    test "does not broadcast for descendant directories updated during move" do
      parent1 = Directory.create!(unique_name())
      parent2 = Directory.create!(unique_name())
      parent_dir = Directory.create!("#{parent1.filename}/subdir")
      parent_dir_id = parent_dir.id
      _child = Directory.create!("#{parent1.filename}/subdir/child")
      _grandchild = Directory.create!("#{parent1.filename}/subdir/child/grandchild")

      # Subscribe to all topics
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")
      Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")

      # Move the parent directory - this will internally update all descendants
      _moved = Directory.move!(parent_dir, %{path: "#{parent2.filename}/subdir"})

      # Should only receive ONE notification for the directory we explicitly moved
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "directory:moved",
                       event: "move",
                       payload: %Phoenix.Socket.Broadcast{
                         payload: %Ash.Notifier.Notification{
                           data: %{id: ^parent_dir_id}
                         }
                       }
                     },
                     100

      # Should NOT receive any additional notifications for descendants
      refute_receive %Phoenix.Socket.Broadcast{}, 100
    end
  end
end
