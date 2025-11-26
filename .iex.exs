import Ecto.Query

require Ash.Query

alias Xeno.Files
alias Files.Directory
alias Xeno.Content
alias Content.Note
alias Content.NoteType

notes_dir = Xeno.notes_dir()
