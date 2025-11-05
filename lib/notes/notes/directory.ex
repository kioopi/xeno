defmodule Notes.Notes.Directory do
  @moduledoc """
  A hierarchical directory structure for organizing notes.

  Directories can be nested to create a tree-like structure, with each directory
  having an optional parent. Root directories have a nil parent_id. Each directory
  has both a user-friendly name and a filesystem-safe filename.

  Uniqueness is enforced on the combination of filename and parent_id, ensuring
  no duplicate filenames exist within the same parent directory or at the root level.
  """
  use Ash.Resource, otp_app: :notes, domain: Notes.Notes, data_layer: AshPostgres.DataLayer

  alias Notes.Notes.Changes

  postgres do
    table "directories"
    repo Notes.Repo
  end

  actions do
    read :read do
      primary? true
      description "Read directories from the database"
    end

    create :create do
      primary? true
      accept [:name, :filename]
      description "Create a new directory"

      change Changes.GenerateName
      change Changes.GenerateFilename
    end

    create :create_child do
      accept [:name, :filename, :parent_id]

      description "Create a new directory as a child of another directory"

      change Changes.GenerateName
      change Changes.GenerateFilename
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "UI friendly name for the directory, may contain spaces and special characters"
    end

    attribute :filename, :string do
      allow_nil? false
      public? true

      description "Filesystem friendly name for the directory, should not contain special characters or spaces"
    end

    timestamps()
  end

  relationships do
    belongs_to :parent, __MODULE__ do
      description "The parent directory of this directory, leave nil for root directories"
    end
  end

  identities do
    identity :unique_filename_per_parent, [:filename, :parent_id] do
      nils_distinct? false

      description "Ensures filename uniqueness within the same parent directory, including root level (nil parent)"
    end
  end
end
