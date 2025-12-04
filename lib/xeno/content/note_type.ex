defmodule Xeno.Content.NoteType do
  @moduledoc """
  A template for creating Notes.

  NoteTypes contain initial values (text, data, tags) that are copied to new Notes
  when they are created. NoteTypes are mutable and can be changed at any time.
  Changes to a NoteType do not affect existing Notes created from it.
  """

  alias Xeno.Content.Calculations

  use Ash.Resource,
    otp_app: :xeno,
    domain: Xeno.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "note_types"
    repo Xeno.Repo
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :by_name, action: :read, get_by: [:name]
    define :list, action: :read
    define :create, action: :create
    define :update, action: :update
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :description, :initial_text, :initial_data, :initial_tags]
    end

    update :update do
      primary? true
      accept [:name, :description, :initial_text, :initial_data, :initial_tags]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Unique name for this note type"
    end

    attribute :description, :string do
      public? true
      description "Optional description of this note type"
    end

    attribute :initial_text, :string do
      public? true
      description "Initial text content for notes created from this type"
    end

    attribute :initial_data, :map do
      public? true
      description "Initial JSON data for notes created from this type"
    end

    attribute :initial_tags, {:array, :string} do
      public? true
      description "Initial tags for notes created from this type"
    end

    timestamps()
  end

  calculations do
    calculate :note_params, :string, Calculations.NoteParams do
      description "Returns params to be used in Note changesets"
    end
  end

  identities do
    identity :unique_name, [:name] do
      description "Ensures NoteType names are unique"
    end
  end
end
