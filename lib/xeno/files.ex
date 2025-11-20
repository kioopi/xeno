defmodule Xeno.Files do
  use Ash.Domain,
    otp_app: :xeno

  resources do
    resource Xeno.Files.Directory do
      define :create_directories_from_filesystem, args: [:path], action: :create_from_filesystem
      define :tree, action: :tree
      define :branch, action: :branch, args: [:root_id]
    end
  end
end
