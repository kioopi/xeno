defmodule Xeno.Content.NotePubSubTest do
  use Xeno.DataCase, async: true

  import Xeno.Generators

  alias Xeno.Content.Note

  setup do
    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:created")
    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:updated")
    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:destroyed")

    directory = generate(directory(path: "pubsub_test"))
    note_type = generate(note_type(name: "PubSub Test"))

    {:ok, directory: directory, note_type: note_type}
  end

  test "broadcasts on note creation", %{directory: dir, note_type: type} do
    note =
      Note.create!(%{
        name: "Broadcast Test",
        directory_id: dir.id,
        note_type_id: type.id
      })

    note_id = note.id

    assert_receive(
      %Phoenix.Socket.Broadcast{
        topic: "note:created",
        event: "create",
        payload: %{id: ^note_id}
      },
      1000
    )
  end

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

    Phoenix.PubSub.subscribe(Xeno.PubSub, "note:updated:#{note.id}")

    {:ok, _updated} = Note.update(note, %{text: "Updated"})

    assert_receive(
      %Phoenix.Socket.Broadcast{
        topic: "note:updated:" <> _
      },
      1000
    )
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
