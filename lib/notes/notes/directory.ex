defmodule Notes.Notes.Directory do
  use Ash.Resource, otp_app: :notes, domain: Notes.Notes, data_layer: AshPostgres.DataLayer

  alias Notes.Notes.Changes

  postgres do
    table "directories"
    repo Notes.Repo
  end

  actions do
    defaults [:read]

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
    identity :unique_filename_per_parent, [:filename, :parent_id], nils_distinct?: false
  end
end
