defmodule XenoWeb.Sync.State do
  @moduledoc """
  Pure functional state management for SyncLive.

  All functions are pure (no side effects) and return new state.
  Side effects (flash, push_event, PubSub) remain in LiveView layer.

  ## State Structure

  The state is organized into four main concerns:

  - `connection` - Directory connection and file watching state
  - `operation` - Import/export operation tracking
  - `preview` - Development preview feature state
  - `conflict` - ID and path conflict resolution state

  ## Invalid Transitions

  Some state transitions are invalid and return error tuples:

  - Starting export while already exporting → `{:error, :operation_in_progress, state}`
  - Starting export while importing → `{:error, :operation_in_progress, state}`
  - Starting import while already importing → `{:error, :operation_in_progress, state}`
  - Starting import while exporting → `{:error, :operation_in_progress, state}`

  ## Noop Operations

  Operations that don't match the current state are noops (return unchanged state):

  - `export_progress/3` when not exporting
  - `import_progress/3` when not importing
  - `import_scan_started/2` when not importing
  - `finish_export/2` when not exporting
  - `complete_import/2` when not importing
  """

  defstruct [:connection, :operation, :preview, :conflict]

  defmodule Connection do
    @moduledoc "Directory connection and file watching state"
    defstruct connected?: false,
              name: nil,
              observer_supported: false,
              watching: false
  end

  defmodule Operation do
    @moduledoc "Import/export operation tracking"
    defstruct mode: :idle,
              phase: :idle,
              started_at: nil,
              last: nil,
              errors: nil

    @type mode :: :idle | :export | :import
    @type phase :: :idle | :scanning | {:running, non_neg_integer(), non_neg_integer()}
  end

  defmodule Last do
    @moduledoc "Most recent completed operation"
    defstruct [:type, :count, :failed, :duration_ms, :at]

    @type t :: %__MODULE__{
            type: :export | :import,
            count: non_neg_integer(),
            failed: non_neg_integer(),
            duration_ms: non_neg_integer(),
            at: DateTime.t()
          }
  end

  defmodule Preview do
    @moduledoc "Development preview feature state"
    defstruct mode: nil, data: nil, selected_id: nil

    @type mode :: nil | :single | :all
  end

  defmodule Conflict do
    @moduledoc "ID and path conflict resolution state"
    defstruct id_conflict: nil, path_mismatch: nil
  end

  @doc """
  Creates a new state with all fields initialized to idle/nil/false.

  ## Examples

      iex> state = State.new()
      iex> state.connection.connected?
      false
      iex> state.operation.mode
      :idle
  """
  def new do
    %__MODULE__{
      connection: %Connection{},
      operation: %Operation{},
      preview: %Preview{},
      conflict: %Conflict{}
    }
  end

  # Connection Management

  @doc """
  Connects to a directory and stores its name.

  ## Examples

      iex> state = State.new()
      iex> state = State.connect(state, "MyNotes")
      iex> state.connection.connected?
      true
      iex> state.connection.name
      "MyNotes"
  """
  def connect(state, name) do
    %{state | connection: %{state.connection | connected?: true, name: name}}
  end

  @doc """
  Disconnects from directory, clearing connection and watching state.
  Preserves observer_supported flag and operation history.

  ## Examples

      iex> state = State.new() |> State.connect("Folder") |> State.disconnect()
      iex> state.connection.connected?
      false
  """
  def disconnect(state) do
    %{state | connection: %{state.connection | connected?: false, name: nil, watching: false}}
  end

  @doc """
  Sets whether FileSystemObserver is supported.

  ## Examples

      iex> state = State.new() |> State.set_observer_support(true)
      iex> state.connection.observer_supported
      true
  """
  def set_observer_support(state, supported?) do
    %{state | connection: %{state.connection | observer_supported: supported?}}
  end

  @doc """
  Enables auto-sync file watching.

  ## Examples

      iex> state = State.new() |> State.start_watching()
      iex> state.connection.watching
      true
  """
  def start_watching(state) do
    %{state | connection: %{state.connection | watching: true}}
  end

  @doc """
  Disables auto-sync file watching.

  ## Examples

      iex> state = State.new() |> State.start_watching() |> State.stop_watching()
      iex> state.connection.watching
      false
  """
  def stop_watching(state) do
    %{state | connection: %{state.connection | watching: false}}
  end

  # Export Lifecycle

  @doc """
  Starts an export operation.

  Returns error tuple if already in an operation.

  ## Examples

      iex> state = State.new()
      iex> state = State.start_export(state, System.monotonic_time(:millisecond))
      iex> state.operation.mode
      :export
  """
  def start_export(state, start_time) do
    case state.operation.mode do
      :idle ->
        %{
          state
          | operation: %{
              state.operation
              | mode: :export,
                started_at: start_time,
                errors: nil
            }
        }

      _ ->
        {:error, :operation_in_progress, state}
    end
  end

  @doc """
  Updates export progress. Noops if not exporting.

  ## Examples

      iex> state = State.new() |> State.start_export(12345)
      iex> state = State.export_progress(state, 5, 10)
      iex> state.operation.phase
      {:running, 5, 10}
  """
  def export_progress(state, current, total) do
    if state.operation.mode == :export do
      %{state | operation: %{state.operation | phase: {:running, current, total}}}
    else
      state
    end
  end

  @doc """
  Finishes export operation, recording duration and count.
  Resets to idle. Noops if not exporting.

  ## Examples

      iex> state = State.new() |> State.start_export(12345)
      iex> state = State.finish_export(state, 10)
      iex> state.operation.mode
      :idle
      iex> state.operation.last.count
      10
  """
  def finish_export(state, count) do
    if state.operation.mode == :export do
      duration_ms = calculate_duration(state.operation.started_at)

      last = %Last{
        type: :export,
        count: count,
        failed: 0,
        duration_ms: duration_ms,
        at: DateTime.utc_now()
      }

      %{
        state
        | operation: %{
            state.operation
            | mode: :idle,
              phase: :idle,
              started_at: nil,
              last: last,
              errors: nil
          }
      }
    else
      state
    end
  end

  @doc """
  Fails export operation with error message. Resets to idle.

  ## Examples

      iex> state = State.new() |> State.start_export(12345)
      iex> state = State.fail_export(state, "Network error")
      iex> state.operation.mode
      :idle
      iex> state.operation.errors
      [%{"type" => "export_error", "message" => "Network error"}]
  """
  def fail_export(state, message) do
    %{
      state
      | operation: %{
          state.operation
          | mode: :idle,
            phase: :idle,
            started_at: nil,
            errors: [%{"type" => "export_error", "message" => message}]
        }
    }
  end

  # Import Lifecycle

  @doc """
  Starts an import operation with scanning phase.

  Returns error tuple if already in an operation.

  ## Examples

      iex> state = State.new()
      iex> state = State.start_import(state, System.monotonic_time(:millisecond))
      iex> state.operation.mode
      :import
      iex> state.operation.phase
      :scanning
  """
  def start_import(state, start_time) do
    case state.operation.mode do
      :idle ->
        %{
          state
          | operation: %{
              state.operation
              | mode: :import,
                phase: :scanning,
                started_at: start_time,
                errors: nil
            }
        }

      _ ->
        {:error, :operation_in_progress, state}
    end
  end

  @doc """
  Transitions from scanning to running phase with total count.
  Noops if not importing.

  ## Examples

      iex> state = State.new() |> State.start_import(12345)
      iex> state = State.import_scan_started(state, 15)
      iex> state.operation.phase
      {:running, 0, 15}
  """
  def import_scan_started(state, total) do
    if state.operation.mode == :import do
      %{state | operation: %{state.operation | phase: {:running, 0, total}}}
    else
      state
    end
  end

  @doc """
  Updates import progress. Noops if not importing.

  ## Examples

      iex> state = State.new() |> State.start_import(12345) |> State.import_scan_started(10)
      iex> state = State.import_progress(state, 5, 10)
      iex> state.operation.phase
      {:running, 5, 10}
  """
  def import_progress(state, current, total) do
    if state.operation.mode == :import do
      %{state | operation: %{state.operation | phase: {:running, current, total}}}
    else
      state
    end
  end

  @doc """
  Completes import operation, processing results and extracting errors.
  Resets to idle. Noops if not importing.

  Results should be a list of maps with "status" key:
  - `%{"status" => "success", "note_id" => ...}`
  - `%{"status" => "error", "error" => %{...}}`

  ## Examples

      iex> state = State.new() |> State.start_import(12345)
      iex> results = [%{"status" => "success"}, %{"status" => "error", "error" => %{}}]
      iex> state = State.complete_import(state, results)
      iex> state.operation.last.count
      1
      iex> state.operation.last.failed
      1
  """
  def complete_import(state, results) do
    if state.operation.mode != :import do
      state
    else
      success_count = Enum.count(results, &(&1["status"] == "success"))
      failed_count = length(results) - success_count

      errors =
        results
        |> Enum.filter(&(&1["status"] == "error"))
        |> Enum.map(& &1["error"])

      duration_ms = calculate_duration(state.operation.started_at)

      last = %Last{
        type: :import,
        count: success_count,
        failed: failed_count,
        duration_ms: duration_ms,
        at: DateTime.utc_now()
      }

      %{
        state
        | operation: %{
            state.operation
            | mode: :idle,
              phase: :idle,
              started_at: nil,
              last: last,
              errors: if(errors == [], do: nil, else: errors)
          }
      }
    end
  end

  @doc """
  Fails import operation with error message. Resets to idle.

  ## Examples

      iex> state = State.new() |> State.start_import(12345)
      iex> state = State.fail_import(state, "Disk full")
      iex> state.operation.mode
      :idle
      iex> state.operation.errors
      [%{"type" => "import_error", "message" => "Disk full"}]
  """
  def fail_import(state, message) do
    %{
      state
      | operation: %{
          state.operation
          | mode: :idle,
            phase: :idle,
            started_at: nil,
            errors: [%{"type" => "import_error", "message" => message}]
        }
    }
  end

  # Conflict Management

  @doc """
  Stores ID conflict data for resolution.

  ## Examples

      iex> state = State.new()
      iex> conflict = %{"server_id" => "s1", "local_id" => "l1"}
      iex> state = State.set_id_conflict(state, conflict)
      iex> state.conflict.id_conflict
      %{"server_id" => "s1", "local_id" => "l1"}
  """
  def set_id_conflict(state, conflict_data) do
    %{state | conflict: %{state.conflict | id_conflict: conflict_data}}
  end

  @doc """
  Clears ID conflict data.

  ## Examples

      iex> state = State.new() |> State.set_id_conflict(%{}) |> State.clear_id_conflict()
      iex> state.conflict.id_conflict
      nil
  """
  def clear_id_conflict(state) do
    %{state | conflict: %{state.conflict | id_conflict: nil}}
  end

  @doc """
  Stores path mismatch data for resolution.

  ## Examples

      iex> state = State.new()
      iex> mismatch = %{"expected" => "/path1", "actual" => "/path2"}
      iex> state = State.set_path_mismatch(state, mismatch)
      iex> state.conflict.path_mismatch
      %{"expected" => "/path1", "actual" => "/path2"}
  """
  def set_path_mismatch(state, mismatch_data) do
    %{state | conflict: %{state.conflict | path_mismatch: mismatch_data}}
  end

  @doc """
  Clears path mismatch data.

  ## Examples

      iex> state = State.new() |> State.set_path_mismatch(%{}) |> State.clear_path_mismatch()
      iex> state.conflict.path_mismatch
      nil
  """
  def clear_path_mismatch(state) do
    %{state | conflict: %{state.conflict | path_mismatch: nil}}
  end

  @doc """
  Clears both ID conflict and path mismatch data.

  ## Examples

      iex> state = State.new()
      iex> |> State.set_id_conflict(%{})
      iex> |> State.set_path_mismatch(%{})
      iex> |> State.clear_all_conflicts()
      iex> state.conflict.id_conflict
      nil
      iex> state.conflict.path_mismatch
      nil
  """
  def clear_all_conflicts(state) do
    %{state | conflict: %{state.conflict | id_conflict: nil, path_mismatch: nil}}
  end

  # Preview Management

  @doc """
  Sets single note preview mode.

  ## Examples

      iex> state = State.new()
      iex> state = State.set_single_preview(state, "note-123", %{"markdown" => "# Test"})
      iex> state.preview.mode
      :single
      iex> state.preview.selected_id
      "note-123"
  """
  def set_single_preview(state, note_id, data) do
    %{state | preview: %{state.preview | mode: :single, selected_id: note_id, data: data}}
  end

  @doc """
  Sets all notes preview mode.

  ## Examples

      iex> state = State.new()
      iex> items = [%{"id" => "1"}, %{"id" => "2"}]
      iex> state = State.set_all_preview(state, items)
      iex> state.preview.mode
      :all
      iex> state.preview.data
      [%{"id" => "1"}, %{"id" => "2"}]
  """
  def set_all_preview(state, items) do
    %{state | preview: %{state.preview | mode: :all, selected_id: nil, data: items}}
  end

  @doc """
  Clears preview mode and data.

  ## Examples

      iex> state = State.new() |> State.set_single_preview("id", %{}) |> State.clear_preview()
      iex> state.preview.mode
      nil
  """
  def clear_preview(state) do
    %{state | preview: %{state.preview | mode: nil, selected_id: nil, data: nil}}
  end

  # Error Management

  @doc """
  Sets a single error message.

  ## Examples

      iex> state = State.new() |> State.set_error("Something went wrong")
      iex> state.operation.errors
      [%{"type" => "error", "message" => "Something went wrong"}]
  """
  def set_error(state, message) do
    %{
      state
      | operation: %{state.operation | errors: [%{"type" => "error", "message" => message}]}
    }
  end

  @doc """
  Clears all errors.

  ## Examples

      iex> state = State.new() |> State.set_error("Error") |> State.clear_errors()
      iex> state.operation.errors
      nil
  """
  def clear_errors(state) do
    %{state | operation: %{state.operation | errors: nil}}
  end

  # Helper Functions

  @doc """
  Calculates duration in milliseconds from start time.
  Returns 0 if start_time is nil.

  ## Examples

      iex> start = System.monotonic_time(:millisecond)
      iex> Process.sleep(100)
      iex> duration = State.calculate_duration(start)
      iex> duration >= 100
      true
  """
  def calculate_duration(nil), do: 0

  def calculate_duration(start_time) do
    System.monotonic_time(:millisecond) - start_time
  end

  @doc """
  Formats duration in milliseconds as human-readable string.

  - < 1s: "500ms"
  - < 60s: "5.5s"
  - >= 60s: "2m 5s"

  ## Examples

      iex> State.format_duration(500)
      "500ms"
      iex> State.format_duration(5_500)
      "5.5s"
      iex> State.format_duration(125_000)
      "2m 5s"
  """
  def format_duration(ms) when ms < 1000, do: "#{ms}ms"

  def format_duration(ms) when ms < 60_000 do
    "#{Float.round(ms / 1000, 1)}s"
  end

  def format_duration(ms) do
    minutes = div(ms, 60_000)
    seconds = div(rem(ms, 60_000), 1000)
    "#{minutes}m #{seconds}s"
  end
end
