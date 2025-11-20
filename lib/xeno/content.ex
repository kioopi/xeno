defmodule Xeno.Content do
  use Ash.Domain,
    otp_app: :xeno

  resources do
    resource Xeno.Content.NoteType
    resource Xeno.Content.Note
  end
end
