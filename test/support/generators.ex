defmodule Xeno.Generators do
  @moduledoc """
  Generators for creating test data for Notes resources using Ash.Generator.

  ## Usage

  Import this module and use `generate/1` or `generate_many/2` with the generator functions:

      import Xeno.Generators

      test "some test" do
        directory = generate(directory())
        note_type = generate(note_type(name: "Custom"))
        note = generate(note(directory_id: directory.id, note_type_id: note_type.id))
      end
  """

  use Ash.Generator

  alias Xeno.Files.Directory
  alias Xeno.Content.{Note, NoteType}

  @doc """
  Generates a Directory resource with random or specified attributes.

  ## Options
  - `:name` - Override the generated name
  - `:filename` - Override the generated filename

  ## Examples

      iex> generate(directory())
      %Xeno.Files.Directory{name: "Notes", path: "notes", filename: "notes"}

      iex> generate(directory(name: "Custom", path: "some/path"))
      %Xeno.Files.Directory{name: "Custom", path: "some/path", filename: "path"}
  """
  def directory(opts \\ []) do
    example_dirs = ~w[Documents Projects Notes Archive Personal Work Ideas Research]

    path_generator =
      Enum.map(example_dirs, &String.downcase/1)
      |> StreamData.member_of()
      |> StreamData.list_of(length: 1..4)
      |> StreamData.nonempty()

    changeset_generator(
      Directory,
      :create,
      uses: [
        defaults: defaults_generator(path_generator)
      ],
      defaults: & &1.defaults,
      overrides: overrides(opts)
    )
  end

  defp defaults_generator(genarator) do
    StreamData.repeatedly(fn ->
      path =
        genarator
        |> Enum.take(1)
        |> List.first()

      [
        path: Path.join(path),
        name: List.last(path) |> String.capitalize()
      ]
    end)
  end

  defp overrides(opts) do
    set_name(opts, opts[:name], opts[:path])
  end

  defp set_name(opts, _, nil), do: opts

  defp set_name(opts, nil, path) do
    name =
      path
      |> String.split("/")
      |> List.last()
      |> String.capitalize()

    Keyword.put(opts, :name, name)
  end

  defp set_name(opts, _, _), do: opts

  @doc """
  Generates a NoteType resource with random or specified attributes.

  ## Options
  - `:name` - Override the generated name
  - `:description` - Override the generated description
  - `:initial_text` - Override the generated initial text
  - `:initial_data` - Override the generated initial data
  - `:initial_tags` - Override the generated initial tags

  ## Examples

      iex> generate(note_type())
      %Xeno.Content.NoteType{name: "Meeting Notes", description: "..."}

      iex> generate(note_type(name: "Custom Type"))
      %Xeno.Content.NoteType{name: "Custom Type"}
  """
  def note_type(opts \\ []) do
    type_names = ~w[
      Meeting\ Notes
      Journal\ Entry
      Task\ List
      Project\ Plan
      Research\ Notes
      Quick\ Note
      Daily\ Log
      Reference
      Ideas
      Empty
    ]

    name_generator = StreamData.member_of(type_names)

    description_generator =
      StreamData.member_of([
        "Template for meeting notes",
        "A journal entry template",
        "Task tracking template",
        "Project planning template",
        "Research note template",
        "Quick note template",
        "Daily log template",
        "Reference material template",
        "Idea capture template",
        "A blank note with no initial content"
      ])

    text_generator =
      StreamData.member_of([
        "# {{title}}\n\n## Content\n\n",
        nil,
        "## Notes\n\n",
        "# Meeting Notes\n\n## Attendees\n\n## Agenda\n\n",
        ""
      ])

    data_generator =
      StreamData.member_of([
        %{},
        %{"template_version" => "1.0"},
        %{"type" => "note"},
        nil
      ])

    tags_generator =
      StreamData.member_of([
        [],
        ["work"],
        ["personal"],
        ["important"],
        ["meeting", "work"],
        nil
      ])

    defaults_gen =
      StreamData.fixed_map(%{
        name: name_generator,
        description: description_generator,
        initial_text: text_generator,
        initial_data: data_generator,
        initial_tags: tags_generator
      })

    changeset_generator(
      NoteType,
      :create,
      uses: [defaults: defaults_gen],
      defaults: & &1.defaults,
      overrides: opts
    )
  end

  @doc """
  Generates a Note resource with random or specified attributes.

  Automatically creates a NoteType and Directory if not provided, using `once/2`
  to ensure they're only created once per test run.

  ## Options
  - `:name` - Override the generated name
  - `:filename` - Override the generated filename
  - `:text` - Override the generated text content
  - `:data` - Override the generated data
  - `:tags` - Override the generated tags
  - `:note_type_id` - Specify the note type ID (auto-generated if not provided)
  - `:directory_id` - Specify the directory ID (auto-generated if not provided)

  ## Examples

      # Simple usage - directory and note_type created automatically
      iex> generate(note())
      %Xeno.Content.Note{name: "My Note", text: "..."}

      # With custom attributes
      iex> generate(note(name: "Custom Note", tags: ["important"]))
      %Xeno.Content.Note{name: "Custom Note", tags: ["important"]}

      # With explicit relationships
      iex> note_type = generate(note_type())
      iex> directory = generate(directory())
      iex> generate(note(note_type_id: note_type.id, directory_id: directory.id))
      %Xeno.Content.Note{name: "My Note", text: "..."}
  """
  def note(opts \\ []) do
    # Auto-generate directory_id if not provided
    directory_id =
      opts[:directory_id] ||
        once(:default_directory_id, fn ->
          generate(directory(path: "test_notes")).id
        end)

    # Auto-generate note_type_id if not provided
    note_type_id =
      opts[:note_type_id] ||
        once(:default_note_type_id, fn ->
          generate(note_type(name: "Default Test Type")).id
        end)

    note_names = ~w[
      My\ Note
      Important\ Task
      Meeting\ Summary
      Project\ Ideas
      Research\ Findings
      Quick\ Reminder
      Daily\ Review
      Notes
      Thoughts
      TODO
    ]

    name_generator = StreamData.member_of(note_names)

    text_generator =
      StreamData.member_of([
        "This is some sample text content.\n\nWith multiple paragraphs.",
        "# Title\n\nSome content here.",
        "Quick note about something important.",
        nil,
        "",
        "* Item 1\n* Item 2\n* Item 3"
      ])

    data_generator =
      StreamData.member_of([
        %{},
        %{"priority" => "high"},
        %{"status" => "active", "count" => 1},
        %{"metadata" => %{"source" => "test"}},
        nil
      ])

    tags_generator =
      StreamData.member_of([
        [],
        ["work"],
        ["personal", "important"],
        ["test", "example"],
        ["urgent"],
        nil
      ])

    defaults_gen =
      StreamData.fixed_map(%{
        overwrite_filename: false,
        name: name_generator,
        text: text_generator,
        data: data_generator,
        tags: tags_generator
      })

    changeset_generator(
      Note,
      :create,
      uses: [defaults: defaults_gen],
      defaults: & &1.defaults,
      overrides: Keyword.merge([directory_id: directory_id, note_type_id: note_type_id], opts)
    )
  end
end
