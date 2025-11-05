defmodule Xeno.Files do
  use Ash.Domain,
    otp_app: :xeno

  resources do
    resource Xeno.Files.Directory
  end
end
