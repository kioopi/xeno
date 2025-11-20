defmodule Xeno.Content.NotePubSubTest do
  use Xeno.DataCase, async: true

  alias Xeno.Content.{Note, NoteType}
  alias Xeno.Files.Directory

  setup do
    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:created")
    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:updated")
    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:destroyed")

    {:ok, directory} = Directory.create("pubsub_test")
    {:ok, note_type} = NoteType.create(%{name: "PubSub Test"})

    {:ok, directory: directory, note_type: note_type}
  end

  test "broadcasts on note creation", %{directory: dir, note_type: type} do
    {:ok, note} =
      Note.create(%{
        name: "Broadcast Test",
        directory_id: dir.id,
        note_type_id: type.id
      })

    assert_receive %Phoenix.Socket.Broadcast{
                     topic: "note:created",
                     event: "create",
                     payload: %Phoenix.Socket.Broadcast{
                       payload: %Ash.Notifier.Notification{
                         data: ^note
                       }
                     }
                   },
                   1000
  end

  @tag :skip
  test "broadcasts on note update", %{directory: dir, note_type: type} do
    {:ok, note} =
      Note.create(%{
        name: "Update Test",
        text: "Original text",
        directory_id: dir.id,
        note_type_id: type.id
      })

    receive do
      %Phoenix.Socket.Broadcast{topic: "note:created"} -> :ok
    after
      100 -> :ok
    end

    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:#{note.id}:updated")

    {:ok, _updated} = Note.update(note, %{text: "Updated"})

    assert_receive %Phoenix.Socket.Broadcast{
                     topic: "note:updated"
                   },
                   1000

    assert_receive %Phoenix.Socket.Broadcast{
                     topic: "note:" <> _
                   },
                   1000
  end

  test "broadcasts on note destruction", %{directory: dir, note_type: type} do
    {:ok, note} =
      Note.create(%{
        name: "Destroy Test",
        directory_id: dir.id,
        note_type_id: type.id
      })

    :ok = Note.destroy(note)

    assert_receive %Phoenix.Socket.Broadcast{
                     topic: "note:destroyed",
                     event: "destroy"
                   },
                   1000
  end
end
