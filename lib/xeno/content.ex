defmodule Xeno.Content do
  use Ash.Domain,
    otp_app: :xeno,
    extensions: [AshPhoenix]

  resources do
    resource Xeno.Content.NoteType

    resource Xeno.Content.Note do
      define :create_note, action: :create
    end
  end
end
