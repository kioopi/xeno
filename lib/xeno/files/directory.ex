defmodule Xeno.Files.Directory do
  @moduledoc """
  A hierarchical directory structure for organizing notes.

  Directories can be nested to create a tree-like structure, with each directory
  having an optional parent. Root directories have a nil parent_id. Each directory
  has both a user-friendly name and a filesystem-safe filename.

  Uniqueness is enforced on the combination of filename and parent_id, ensuring
  no duplicate filenames exist within the same parent directory or at the root level.
  """
  use Ash.Resource, otp_app: :xeno, domain: Xeno.Files, data_layer: AshPostgres.DataLayer

  alias Xeno.Files
  alias Files.Changes
  alias Files.Directory.RecursiveCreate

  require Ash.Query

  postgres do
    table "directories"
    repo Xeno.Repo

    custom_indexes do
      index :path, using: "GIST"
    end
  end

  code_interface do
    define :get_or_create, action: :upsert, args: [:path]
    define :create, action: :create, args: [:path]
    define :create_from_filesystem, args: [:path]
    define :by_path, args: [:path], get?: true
  end

  actions do
    defaults [:destroy, update: [:name]]

    read :read do
      primary? true
      description "Read directories from the database"
    end

    create :create do
      primary? true
      accept [:name]
      description "Create a new directory"

      argument :path, :string do
        allow_nil? false

        constraints match: ~r/^[[:alnum:]\/_]*$/,
                    min_length: 3
      end

      change Changes.SetPath
    end

    create :upsert do
      description "Creates a new directory unless the same filename exists within the same parent directory, in which case it returns the existing directory."

      accept [:name]

      argument :path, :string do
        allow_nil? false
      end

      upsert? true
      upsert_identity :unique_path
      upsert_fields {:replace_all_except, [:name, :updated_at, :inserted_at, :id]}

      change Changes.SetPath
    end

    action :create_from_filesystem, {:array, :struct} do
      constraints items: [instance_of: __MODULE__]

      argument :path, :string do
        allow_nil? false
        description "Absolute filesystem path to scan for subdirectories"
      end

      description "Recursively creates Directory records for all subdirectories found in the given filesystem path"

      validate {Files.Validations.PathExists, arg: :path}
      prepare {Files.Directory.SubdirsOf, arg: :path}

      run fn _input, context ->
        RecursiveCreate.create_directories(context.source_context.directories)
      end
    end

    read :by_path do
      description "Read a directory by its filesystem path"

      argument :path, :string do
        allow_nil? false
      end

      prepare fn %{arguments: args} = query, _context ->
        Ash.Query.filter(query, path: [eq: path_to_ltree(args.path)])
      end
    end
  end

  preparations do
    prepare build(load: [:filename])
  end

  changes do
    change load(:filename) do
      on [:create, :update]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "UI friendly name for the directory, may contain spaces and special characters"
    end

    attribute :path, AshPostgres.Ltree do
      allow_nil? false
      description "filesystem path to the directory"
    end

    timestamps()
  end

  relationships do
    has_one :parent, __MODULE__ do
      no_attributes? true

      filter expr(
               fragment(
                 "(ltree2text(?) || '.' || ?)::lquery ~ ?",
                 path,
                 # parent() is self
                 parent(filename),
                 parent(path)
               )
             )

      description "The parent directory of this directory, leave nil for root directories"
    end

    has_many :children, __MODULE__ do
      no_attributes? true
      filter expr(fragment("? ~ (ltree2text(?) || '.*{1}')::lquery", path, parent(path)))
      sort path: :desc
      description "The list of directories contained by this directory"
    end

    has_many :descendants, __MODULE__ do
      no_attributes? true
      filter expr(fragment("? <@ ?", path, parent(path)))
      sort path: :desc
      description "The list of descendant directories contained by this directory at any level"
    end
  end

  calculations do
    calculate :filename, :string, expr(fragment("subpath(?, -1)", path))

    calculate :filesystem_path,
              :string,
              expr(fragment("'/' || replace(ltree2text(?), '.', '/')", path))

    calculate :depth, :integer, expr(fragment("nlevel(?)", path))
  end

  identities do
    identity :unique_path, [:path] do
      description "Ensures directory paths have to be unique"
    end
  end

  def path_to_ltree(nil), do: nil

  def path_to_ltree(path) do
    path |> Path.split() |> Enum.filter(&(&1 != "/"))
  end
end
