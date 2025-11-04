defmodule Notes.Notes do
  use Ash.Domain,
    otp_app: :notes

  resources do
    resource Notes.Notes.Directory
  end
end
