defmodule Xeno.Content.Note do
  @moduledoc """
  A note with plaintext content and custom JSON data.

  Notes are always created from a NoteType template and belong to a Directory.
  They support optimistic locking to prevent lost updates in concurrent editing scenarios.
  """
  use Ash.Resource,
    otp_app: :xeno,
    domain: Xeno.Content,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias Xeno.Content.Changes
  alias Xeno.Content.Calculations
  alias Xeno.Content.Preparations
  alias Xeno.Files.Directory
  alias Xeno.Content.NoteType

  postgres do
    table "notes"
    repo Xeno.Repo
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :by_filename, action: :read, get_by: [:directory_id, :filename]
    define :by_file_path, action: :by_file_path, args: [:file_path]
    define :in_directory, action: :read, args: [:directory_id]
    define :create, action: :create
    define :update, action: :update
    define :import_from_filesystem, action: :import_from_filesystem
    define :destroy, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    read :by_file_path do
      description "Find a note by its full file path (directory/path/filename)"

      argument :file_path, :string do
        allow_nil? false
        description "Full file path including directory and filename"
      end

      get? true

      prepare Preparations.ParseFilePath
    end

    create :create do
      primary? true
      accept [:name, :filename, :text, :data, :tags]

      argument :note_type_id, :uuid do
        allow_nil? false
      end

      argument :directory_id, :uuid do
        allow_nil? false
      end

      change Changes.GenerateFilename, where: [changing(:name), negate(changing(:filename))]
      change Changes.InitializeFromType
      change Changes.NormalizeTags, where: changing(:tags)

      change manage_relationship(:directory_id, :directory, type: :append)
    end

    update :update do
      primary? true
      accept [:name, :text, :data, :tags]
      require_atomic? false

      change Changes.NormalizeTags, where: changing(:tags)
    end

    update :update_from_fs do
      description "Internal update action for filesystem imports"

      argument :markdown_content, :string do
        allow_nil? false
        description "Raw markdown content from .md file"
      end

      argument :path, :string do
        description "File path for logging/debugging"
      end

      argument :version, :integer do
        description "Expected version for optimistic locking"
      end

      accept [:name, :text, :data, :tags]
      require_atomic? false

      change Changes.ParseMarkdown
      change Changes.NormalizeTags, where: changing(:tags)
      change optimistic_lock(:version)
    end

    action :import_from_filesystem, :struct do
      description "Import note changes from file system with ID resolution"
      constraints instance_of: __MODULE__

      argument :id, :uuid do
        allow_nil? false
        description "ID of the note to update"
      end

      argument :path, :string do
        description "File path for ID suggestion if lookup fails"
      end

      argument :markdown_content, :string do
        allow_nil? false
        description "Raw markdown content from .md file"
      end

      argument :name, :string, description: "Updated name"
      argument :tags, {:array, :string}, description: "Updated tags"
      argument :data, :map, description: "Updated data"
      argument :version, :integer, description: "Version for optimistic locking"

      run fn input, _context ->
        case Xeno.Content.IdResolver.resolve(input.arguments.id, input.arguments.path) do
          {:ok, note} ->
            note_with_version =
              if input.arguments.version do
                %{note | version: input.arguments.version}
              else
                note
              end

            update_attrs = prepare_update_attrs(input.arguments)

            case note_with_version
                 |> Ash.Changeset.for_update(:update_from_fs, update_attrs)
                 |> Ash.update() do
              {:ok, updated_note} -> {:ok, updated_note}
              {:error, error} -> {:error, error}
            end

          {:path_mismatch, note, expected_path} ->
            note = Ash.load!(note, :file_path)

            {:error,
             Xeno.Content.Errors.PathMismatch.exception(
               note_id: note.id,
               expected_path: note.file_path,
               actual_path: expected_path,
               note_name: note.name
             )}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defp prepare_update_attrs(arguments) do
    %{
      markdown_content: arguments.markdown_content,
      name: Map.get(arguments, :name),
      tags: Map.get(arguments, :tags),
      data: Map.get(arguments, :data),
      path: Map.get(arguments, :path)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  pub_sub do
    module XenoWeb.Endpoint
    prefix "note"

    transform fn notification ->
      Map.take(notification.data, [:id])
    end

    publish :create, "created"
    publish :update, ["updated", ["updated", :id]]
    publish :destroy, "destroyed"
  end

  changes do
    change load([:directory, :note_type]) do
      on [:create, :update]
    end

    change optimistic_lock(:version), on: [:update, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Human-readable name for the note"
    end

    attribute :filename, :string do
      allow_nil? false
      public? true
      description "Filesystem-safe filename (auto-generated from name if not provided)"
    end

    attribute :text, :string do
      public? true
      description "Plaintext content of the note"
    end

    attribute :data, :map do
      public? true
      description "Custom JSON data"
    end

    attribute :tags, {:array, :string} do
      public? true
      description "List of tags (normalized to lowercase)"
      constraints items: [allow_empty?: true]
    end

    attribute :version, :integer do
      allow_nil? false
      default 1
      public? true
      description "Version number for optimistic locking"
    end

    timestamps()
  end

  relationships do
    belongs_to :directory, Directory do
      allow_nil? false
      public? true
      description "The directory containing this note"
    end

    belongs_to :note_type, NoteType do
      allow_nil? false
      public? true
      description "The note type template this note was created from"
    end
  end

  calculations do
    calculate :file_path, :string, Calculations.FilePath do
      description "Full file path without extension (directory path + filename)"
    end
  end

  identities do
    identity :unique_filename_in_directory, [:directory_id, :filename] do
      description "Ensures filenames are unique within a directory"
    end
  end
end
