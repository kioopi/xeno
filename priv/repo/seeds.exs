# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Xeno.Repo.insert!(%Xeno.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Xeno.Content.NoteType

# Create default "Empty" NoteType
case NoteType.by_name("Empty") do
  {:ok, _note_type} ->
    IO.puts("Empty NoteType already exists")

  {:error, _} ->
    {:ok, _note_type} =
      NoteType.create(%{
        name: "Empty",
        description: "A blank note with no initial content"
      })

    IO.puts("Created Empty NoteType")
end
