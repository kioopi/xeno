defmodule Xeno.Notes do
  use Ash.Domain,
    otp_app: :xeno

  resources do
    resource Xeno.Notes.Directory
  end
end
