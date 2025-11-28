defmodule Xeno.Files.Directory do
  @moduledoc """
  A hierarchical directory structure for organizing notes.

  Directories can be nested to create a tree-like structure, with each directory
  having an optional parent. Root directories have a nil parent_id. Each directory
  has both a user-friendly name and a filesystem-safe filename.

  Uniqueness is enforced on the combination of filename and parent_id, ensuring
  no duplicate filenames exist within the same parent directory or at the root level.
  """
  use Ash.Resource,
    otp_app: :xeno,
    domain: Xeno.Files,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias Xeno.Files
  alias Files.Changes
  alias Files.Directory
  alias Directory.RecursiveCreate

  require Ash.Query

  postgres do
    table "directories"
    repo Xeno.Repo

    custom_indexes do
      index :path_ltree, using: "GIST"
    end
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :get_or_create, action: :upsert, args: [:path]
    define :create, action: :create, args: [:path]
    define :create_from_filesystem, args: [:path]
    define :by_path, args: [:path], get?: true
    define :descendants_of, args: [:parent]
    define :update, action: :update
    define :move, action: :move
    define :destroy, action: :destroy
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
      description "Creates a new directory unless the same path exists, in which case it returns the existing directory."

      accept [:name]

      argument :path, :string do
        allow_nil? false

        constraints match: ~r/^[[:alnum:]\/_]*$/,
                    min_length: 3
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

        constraints match: ~r/^[[:alnum:]\/_]*$/,
                    min_length: 3
      end

      prepare fn %{arguments: args} = query, _context ->
        Ash.Query.put_context(query, :path, path_to_ltree(args.path))
      end

      filter expr(path_ltree == ^context(:path))
    end

    read :descendants_of do
      description "Read a directory by its filesystem path"
      pagination offset?: true, keyset?: true, required?: false

      argument :parent, :struct do
        allow_nil? false
        constraints instance_of: __MODULE__
      end

      prepare fn %{arguments: args} = query, _context ->
        {:ok, ltree} = AshPostgres.Ltree.dump_to_native(args.parent.path_ltree, nil)

        query
        |> Ash.Query.put_context(:path_ltree, ltree)
        |> Ash.Query.put_context(:id, args.parent.id)
      end

      prepare build(sort: [:path_ltree])

      filter expr(
               fragment("? <@ ?", path_ltree, ^context(:path_ltree)) and
                 id != ^context(:id)
             )
    end

    update :move do
      description "Move a directory to a new parent directory"
      require_atomic? false

      argument :path, :string do
        allow_nil? false

        constraints match: ~r/^[[:alnum:]\/_]*$/,
                    min_length: 3
      end

      change Changes.SetPath
      change Changes.MoveDescendants
    end

    update :parent_moved do
      require_atomic? false

      description """
        Used in the MoveDescendants change to update the path_ltree after the parent has moved.
        Requires a calculation `new_path` to be defined that provides the updated path_ltree value.
        I see no reason why this couldn't be atomic but the Ltree Type does not support it.
      """

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(
          changeset,
          :path_ltree,
          changeset.data.calculations.new_path
        )
      end
    end

    action :tree, {:array, :term} do
      description "Build hierarchical tree structure from all directories"

      argument :transform, :term do
        allow_nil? true
        description "Optional function to transform each directory record in the tree"
      end

      run fn input, _context ->
        transform_fn = input.arguments[:transform] || fn dir -> dir end

        dirs =
          __MODULE__
          |> Ash.Query.sort(:path_ltree)
          |> Ash.Query.load([:depth, :parent])
          |> Ash.read!()

        tree = Directory.Tree.build_from_list(dirs, transform_fn)

        {:ok, tree}
      end
    end

    action :branch, :term do
      description "Build tree branch for a specific root directory and all its descendants"

      argument :root_id, :uuid do
        allow_nil? false
        description "The ID of the root directory to build a branch for"
      end

      run fn input, _context ->
        root =
          Ash.get!(
            __MODULE__,
            input.arguments.root_id,
            load: [:depth, :parent]
          )

        descendants =
          __MODULE__
          |> Ash.Query.for_read(:descendants_of, %{parent: root})
          |> Ash.read!()
          |> Ash.load!([:depth, :parent])

        branch = Directory.Tree.build_branch_from_list(root, descendants)

        {:ok, branch}
      end
    end
  end

  pub_sub do
    module XenoWeb.Endpoint
    prefix "directory"

    publish :create, "created"
    publish :update, "updated"
    publish :move, "moved"
    publish :destroy, "destroyed"

    broadcast_type :phoenix_broadcast
  end

  preparations do
    prepare build(load: [:filename, :path])
  end

  changes do
    change load([:filename, :path]) do
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

    attribute :path_ltree, AshPostgres.Ltree do
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
                 path_ltree,
                 # parent() is self
                 parent(filename),
                 parent(path_ltree)
               )
             )

      description "The parent directory of this directory, leave nil for root directories"
    end

    has_one :root_ancestor, __MODULE__ do
      no_attributes? true

      filter expr(path_ltree == parent(root_path))

      description "The root directory ancestor for this directory (uses root_path calculation)"
    end

    has_many :children, __MODULE__ do
      no_attributes? true

      filter expr(
               fragment("? ~ (ltree2text(?) || '.*{1}')::lquery", path_ltree, parent(path_ltree))
             )

      sort path_ltree: :desc
      description "The list of directories contained by this directory"
    end

    has_many :descendants, __MODULE__ do
      no_attributes? true
      filter expr(fragment("? <@ ?", path_ltree, parent(path_ltree)) and not id == parent(id))
      sort path_ltree: :desc
      description "The list of descendant directories contained by this directory at any level"
    end

    has_many :notes, Xeno.Content.Note do
      public? true
      description "The notes in this directory"
      sort updated_at: :desc
    end
  end

  calculations do
    calculate :filename, :string, Directory.Filename
    calculate :path, :string, Directory.Path
    calculate :depth, :integer, Directory.Depth
    calculate :root_path, AshPostgres.Ltree, Directory.RootPath
  end

  identities do
    identity :unique_path, [:path_ltree] do
      description "Ensures directory paths have to be unique"
    end
  end

  def path_to_ltree(nil), do: nil

  def path_to_ltree(path) do
    path |> Path.split() |> Enum.filter(&(&1 != "/"))
  end
end
