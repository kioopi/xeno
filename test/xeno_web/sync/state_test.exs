defmodule XenoWeb.Sync.StateTest do
  use ExUnit.Case, async: true

  alias XenoWeb.Sync.State

  describe "new/0" do
    test "returns initial state with all fields idle/nil/false" do
      state = State.new()

      # Connection
      assert state.connection.connected? == false
      assert state.connection.name == nil
      assert state.connection.observer_supported == false
      assert state.connection.watching == false

      # Operation
      assert state.operation.mode == :idle
      assert state.operation.phase == :idle
      assert state.operation.started_at == nil
      assert state.operation.last == nil
      assert state.operation.errors == nil

      # Preview
      assert state.preview.mode == nil
      assert state.preview.data == nil
      assert state.preview.selected_id == nil

      # Conflict
      assert state.conflict.id_conflict == nil
      assert state.conflict.path_mismatch == nil
    end
  end

  describe "connection management" do
    test "connect/2 sets connected to true and stores directory name" do
      state = State.new()
      result = State.connect(state, "MyNotes")

      assert result.connection.connected? == true
      assert result.connection.name == "MyNotes"
    end

    test "connect/2 works without directory name (nil)" do
      state = State.new()
      result = State.connect(state, nil)

      assert result.connection.connected? == true
      assert result.connection.name == nil
    end

    test "connecting does not affect operation or preview state" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.connect(state, "Folder")

      assert result.operation.mode == :export
      assert result.connection.connected? == true
    end

    test "disconnect/1 resets connection state and clears watching" do
      state =
        State.new()
        |> State.connect("Folder")
        |> State.start_watching()

      result = State.disconnect(state)

      assert result.connection.connected? == false
      assert result.connection.name == nil
      assert result.connection.watching == false
    end

    test "disconnect/1 preserves observer_supported flag" do
      state =
        State.new()
        |> State.connect("Folder")
        |> State.set_observer_support(true)

      result = State.disconnect(state)

      assert result.connection.observer_supported == true
    end

    test "disconnect/1 does not clear operation history (last)" do
      state =
        State.new()
        |> State.connect("Folder")
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(10)

      result = State.disconnect(state)

      assert result.operation.last != nil
      assert result.operation.last.count == 10
    end

    test "set_observer_support/2 sets flag to true" do
      state = State.new()
      result = State.set_observer_support(state, true)

      assert result.connection.observer_supported == true
    end

    test "set_observer_support/2 sets flag to false" do
      state = State.new() |> State.set_observer_support(true)
      result = State.set_observer_support(state, false)

      assert result.connection.observer_supported == false
    end

    test "start_watching/1 enables watching" do
      state = State.new()
      result = State.start_watching(state)

      assert result.connection.watching == true
    end

    test "stop_watching/1 disables watching" do
      state = State.new() |> State.start_watching()
      result = State.stop_watching(state)

      assert result.connection.watching == false
    end

    test "watching survives across operations" do
      state =
        State.new()
        |> State.start_watching()
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(5)

      assert state.connection.watching == true
    end

    test "disconnect clears watching but preserves operation history and observer support" do
      state =
        State.new()
        |> State.connect("MyFolder")
        |> State.set_observer_support(true)
        |> State.start_watching()
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(10)

      result = State.disconnect(state)

      assert result.connection.connected? == false
      assert result.connection.watching == false
      assert result.connection.observer_supported == true
      assert result.operation.last.count == 10
    end
  end

  describe "export lifecycle" do
    test "start_export/2 sets mode to export and records start time" do
      start_time = System.monotonic_time(:millisecond)
      state = State.new()
      result = State.start_export(state, start_time)

      assert result.operation.mode == :export
      assert result.operation.started_at == start_time
    end

    test "start_export/2 returns error tuple when already exporting" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_export(state, System.monotonic_time(:millisecond))

      assert returned_state == state
    end

    test "start_export/2 returns error tuple when importing" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_export(state, System.monotonic_time(:millisecond))

      assert returned_state == state
      assert returned_state.operation.mode == :import
    end

    test "start_export/2 clears previous errors" do
      state = State.new() |> State.set_error("Previous error")
      result = State.start_export(state, System.monotonic_time(:millisecond))

      assert result.operation.errors == nil
    end

    test "export_progress/3 updates phase with {running, current, total}" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.export_progress(state, 5, 10)

      assert result.operation.phase == {:running, 5, 10}
    end

    test "export_progress/3 works when already in progress (updates current)" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.export_progress(3, 10)

      result = State.export_progress(state, 7, 10)

      assert result.operation.phase == {:running, 7, 10}
    end

    test "export_progress/3 noops if not exporting (returns unchanged state)" do
      state = State.new()
      result = State.export_progress(state, 5, 10)

      assert result == state
      assert result.operation.phase == :idle
    end

    test "finish_export/2 records last operation with count, duration, timestamp" do
      start_time = System.monotonic_time(:millisecond)
      state = State.new() |> State.start_export(start_time)

      Process.sleep(50)
      result = State.finish_export(state, 10)

      assert result.operation.last.type == :export
      assert result.operation.last.count == 10
      assert result.operation.last.failed == 0
      assert result.operation.last.duration_ms >= 50
      assert %DateTime{} = result.operation.last.at
    end

    test "finish_export/2 resets to idle mode and clears started_at" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.finish_export(state, 5)

      assert result.operation.mode == :idle
      assert result.operation.phase == :idle
      assert result.operation.started_at == nil
    end

    test "finish_export/2 clears errors on successful completion" do
      state =
        State.new()
        |> State.set_error("Old error")
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.finish_export(state, 5)

      assert result.operation.errors == nil
    end

    test "finish_export/2 handles zero count" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.finish_export(state, 0)

      assert result.operation.last.count == 0
    end

    test "finish_export/2 noops if not exporting" do
      state = State.new()
      result = State.finish_export(state, 10)

      assert result == state
      assert result.operation.last == nil
    end

    test "fail_export/2 resets to idle and stores error message" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.fail_export(state, "Export failed")

      assert result.operation.mode == :idle
      assert result.operation.phase == :idle
      assert is_list(result.operation.errors)
      assert hd(result.operation.errors)["message"] == "Export failed"
    end

    test "fail_export/2 preserves last successful operation" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(5)
        |> State.start_export(System.monotonic_time(:millisecond))

      result = State.fail_export(state, "Failed")

      assert result.operation.last.count == 5
    end

    test "can start new export after failure" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.fail_export("Failed")

      result = State.start_export(state, System.monotonic_time(:millisecond))

      assert result.operation.mode == :export
    end

    test "complete export flow captures duration" do
      start_time = System.monotonic_time(:millisecond)

      state =
        State.new()
        |> State.start_export(start_time)
        |> State.export_progress(5, 10)

      Process.sleep(100)

      result = State.finish_export(state, 10)

      assert result.operation.mode == :idle
      assert result.operation.phase == :idle
      assert result.operation.started_at == nil

      assert result.operation.last.type == :export
      assert result.operation.last.count == 10
      assert result.operation.last.failed == 0
      assert result.operation.last.duration_ms >= 100
      assert %DateTime{} = result.operation.last.at
    end
  end

  describe "import lifecycle" do
    test "start_import/2 sets mode to import, phase to scanning" do
      start_time = System.monotonic_time(:millisecond)
      state = State.new()
      result = State.start_import(state, start_time)

      assert result.operation.mode == :import
      assert result.operation.phase == :scanning
      assert result.operation.started_at == start_time
    end

    test "start_import/2 returns error when already importing" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_import(state, System.monotonic_time(:millisecond))

      assert returned_state == state
    end

    test "start_import/2 returns error when exporting" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_import(state, System.monotonic_time(:millisecond))

      assert returned_state.operation.mode == :export
    end

    test "start_import/2 clears previous errors" do
      state = State.new() |> State.set_error("Old error")
      result = State.start_import(state, System.monotonic_time(:millisecond))

      assert result.operation.errors == nil
    end

    test "import_scan_started/2 sets phase to {running, 0, total}" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      result = State.import_scan_started(state, 15)

      assert result.operation.phase == {:running, 0, 15}
    end

    test "import_scan_started/2 noops if not importing" do
      state = State.new()
      result = State.import_scan_started(state, 10)

      assert result == state
      assert result.operation.phase == :idle
    end

    test "import_progress/3 updates phase with current count" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))
        |> State.import_scan_started(10)

      result = State.import_progress(state, 5, 10)

      assert result.operation.phase == {:running, 5, 10}
    end

    test "import_progress/3 noops if not importing" do
      state = State.new()
      result = State.import_progress(state, 5, 10)

      assert result == state
    end

    test "complete_import/2 processes results and counts successes/failures" do
      start = System.monotonic_time(:millisecond)

      state =
        State.new()
        |> State.start_import(start)
        |> State.import_scan_started(5)

      results = [
        %{"status" => "success", "note_id" => "n1"},
        %{"status" => "success", "note_id" => "n2"},
        %{"status" => "error", "error" => %{"type" => "validation"}},
        %{"status" => "success", "note_id" => "n3"}
      ]

      Process.sleep(50)
      result = State.complete_import(state, results)

      assert result.operation.mode == :idle
      assert result.operation.last.type == :import
      assert result.operation.last.count == 3
      assert result.operation.last.failed == 1
      assert result.operation.last.duration_ms >= 50
    end

    test "complete_import/2 extracts error details from failed results" do
      start = System.monotonic_time(:millisecond)

      state =
        State.new()
        |> State.start_import(start)
        |> State.import_scan_started(5)

      results = [
        %{"status" => "success", "note_id" => "n1"},
        %{"status" => "error", "error" => %{"type" => "validation", "message" => "Bad"}},
        %{"status" => "success", "note_id" => "n2"},
        %{"status" => "error", "error" => %{"type" => "id_not_found", "message" => "Missing"}}
      ]

      Process.sleep(50)
      result = State.complete_import(state, results)

      assert length(result.operation.errors) == 2
      assert Enum.any?(result.operation.errors, &(&1["type"] == "validation"))
      assert Enum.any?(result.operation.errors, &(&1["type"] == "id_not_found"))
    end

    test "complete_import/2 computes duration and creates last operation" do
      start = System.monotonic_time(:millisecond)

      state =
        State.new()
        |> State.start_import(start)

      Process.sleep(75)

      results = [
        %{"status" => "success", "note_id" => "n1"}
      ]

      result = State.complete_import(state, results)

      assert result.operation.last.duration_ms >= 75
      assert %DateTime{} = result.operation.last.at
    end

    test "complete_import/2 resets to idle and clears started_at" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      result = State.complete_import(state, [])

      assert result.operation.mode == :idle
      assert result.operation.phase == :idle
      assert result.operation.started_at == nil
    end

    test "complete_import/2 handles all successful imports" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      results = [
        %{"status" => "success", "note_id" => "n1"},
        %{"status" => "success", "note_id" => "n2"}
      ]

      result = State.complete_import(state, results)

      assert result.operation.last.count == 2
      assert result.operation.last.failed == 0
      assert result.operation.errors == nil
    end

    test "complete_import/2 handles all failed imports" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      results = [
        %{"status" => "error", "error" => %{"type" => "e1"}},
        %{"status" => "error", "error" => %{"type" => "e2"}}
      ]

      result = State.complete_import(state, results)

      assert result.operation.last.count == 0
      assert result.operation.last.failed == 2
      assert length(result.operation.errors) == 2
    end

    test "complete_import/2 handles empty results (no changes)" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      result = State.complete_import(state, [])

      assert result.operation.last.count == 0
      assert result.operation.last.failed == 0
      assert result.operation.errors == nil
    end

    test "complete_import/2 sets errors to nil when all succeed" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      results = [%{"status" => "success", "note_id" => "n1"}]

      result = State.complete_import(state, results)

      assert result.operation.errors == nil
    end

    test "complete_import/2 noops if not importing" do
      state = State.new()
      result = State.complete_import(state, [])

      assert result == state
      assert result.operation.last == nil
    end

    test "fail_import/2 resets to idle and stores error message" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      result = State.fail_import(state, "Import failed")

      assert result.operation.mode == :idle
      assert result.operation.phase == :idle
      assert is_list(result.operation.errors)
      assert hd(result.operation.errors)["message"] == "Import failed"
    end

    test "can start new import after failure" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))
        |> State.fail_import("Failed")

      result = State.start_import(state, System.monotonic_time(:millisecond))

      assert result.operation.mode == :import
    end
  end

  describe "conflict management" do
    test "set_id_conflict/2 stores conflict data with all fields" do
      state = State.new()
      conflict = %{"server_id" => "s1", "local_id" => "l1", "path" => "/test.md"}

      result = State.set_id_conflict(state, conflict)

      assert result.conflict.id_conflict == conflict
    end

    test "set_id_conflict/2 replaces existing conflict" do
      state = State.new() |> State.set_id_conflict(%{"old" => "conflict"})
      new_conflict = %{"new" => "conflict"}

      result = State.set_id_conflict(state, new_conflict)

      assert result.conflict.id_conflict == new_conflict
    end

    test "clear_id_conflict/1 removes conflict" do
      state = State.new() |> State.set_id_conflict(%{"test" => "conflict"})

      result = State.clear_id_conflict(state)

      assert result.conflict.id_conflict == nil
    end

    test "clear_id_conflict/1 is idempotent" do
      state = State.new()

      result = State.clear_id_conflict(state)

      assert result.conflict.id_conflict == nil
    end

    test "set_path_mismatch/2 stores mismatch data" do
      state = State.new()
      mismatch = %{"expected" => "/path1", "actual" => "/path2"}

      result = State.set_path_mismatch(state, mismatch)

      assert result.conflict.path_mismatch == mismatch
    end

    test "clear_path_mismatch/1 removes mismatch" do
      state = State.new() |> State.set_path_mismatch(%{"test" => "mismatch"})

      result = State.clear_path_mismatch(state)

      assert result.conflict.path_mismatch == nil
    end

    test "clear_all_conflicts/1 clears both id_conflict and path_mismatch" do
      state =
        State.new()
        |> State.set_id_conflict(%{"id" => "conflict"})
        |> State.set_path_mismatch(%{"path" => "mismatch"})

      result = State.clear_all_conflicts(state)

      assert result.conflict.id_conflict == nil
      assert result.conflict.path_mismatch == nil
    end

    test "clear_all_conflicts/1 is idempotent" do
      state = State.new()

      result = State.clear_all_conflicts(state)

      assert result.conflict.id_conflict == nil
      assert result.conflict.path_mismatch == nil
    end
  end

  describe "preview management" do
    test "set_single_preview/3 sets mode to :single with data and selected_id" do
      state = State.new()
      note_id = "note-123"
      data = %{"markdown" => "# Test", "json" => %{}}

      result = State.set_single_preview(state, note_id, data)

      assert result.preview.mode == :single
      assert result.preview.selected_id == note_id
      assert result.preview.data == data
    end

    test "set_single_preview/3 replaces existing preview" do
      state = State.new() |> State.set_single_preview("old", %{"old" => "data"})

      result = State.set_single_preview(state, "new", %{"new" => "data"})

      assert result.preview.selected_id == "new"
      assert result.preview.data == %{"new" => "data"}
    end

    test "set_all_preview/2 sets mode to :all with items" do
      state = State.new()
      items = [%{"id" => "1"}, %{"id" => "2"}]

      result = State.set_all_preview(state, items)

      assert result.preview.mode == :all
      assert result.preview.data == items
      assert result.preview.selected_id == nil
    end

    test "set_all_preview/2 handles empty list" do
      state = State.new()

      result = State.set_all_preview(state, [])

      assert result.preview.mode == :all
      assert result.preview.data == []
    end

    test "clear_preview/1 resets all preview fields to nil" do
      state = State.new() |> State.set_single_preview("id", %{"data" => "test"})

      result = State.clear_preview(state)

      assert result.preview.mode == nil
      assert result.preview.data == nil
      assert result.preview.selected_id == nil
    end

    test "clear_preview/1 is idempotent" do
      state = State.new()

      result = State.clear_preview(state)

      assert result.preview.mode == nil
    end
  end

  describe "error management" do
    test "set_error/2 stores single error message as list" do
      state = State.new()

      result = State.set_error(state, "Something went wrong")

      assert is_list(result.operation.errors)
      assert length(result.operation.errors) == 1
      assert hd(result.operation.errors)["message"] == "Something went wrong"
    end

    test "set_error/2 replaces previous errors" do
      state = State.new() |> State.set_error("Old error")

      result = State.set_error(state, "New error")

      assert length(result.operation.errors) == 1
      assert hd(result.operation.errors)["message"] == "New error"
    end

    test "clear_errors/1 removes all errors" do
      state = State.new() |> State.set_error("Error")

      result = State.clear_errors(state)

      assert result.operation.errors == nil
    end

    test "clear_errors/1 is idempotent" do
      state = State.new()

      result = State.clear_errors(state)

      assert result.operation.errors == nil
    end
  end

  describe "helper functions" do
    test "calculate_duration/1 computes milliseconds elapsed" do
      start = System.monotonic_time(:millisecond)
      Process.sleep(100)

      duration = State.calculate_duration(start)

      assert duration >= 100
      assert duration < 200
    end

    test "calculate_duration/1 returns 0 for nil start time" do
      assert State.calculate_duration(nil) == 0
    end

    test "format_duration/1 formats milliseconds for < 1s" do
      assert State.format_duration(0) == "0ms"
      assert State.format_duration(500) == "500ms"
      assert State.format_duration(999) == "999ms"
    end

    test "format_duration/1 formats seconds for < 60s" do
      assert State.format_duration(1_000) == "1.0s"
      assert State.format_duration(5_500) == "5.5s"
      assert State.format_duration(45_300) == "45.3s"
      assert State.format_duration(59_000) == "59.0s"
    end

    test "format_duration/1 formats minutes for >= 60s" do
      assert State.format_duration(60_000) == "1m 0s"
      assert State.format_duration(125_000) == "2m 5s"
      assert State.format_duration(3_661_000) == "61m 1s"
    end
  end

  describe "invalid transitions" do
    test "cannot start export while exporting - returns error tuple" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_export(state, System.monotonic_time(:millisecond))

      assert returned_state == state
      assert returned_state.operation.mode == :export
    end

    test "cannot start export while importing - returns error tuple" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_export(state, System.monotonic_time(:millisecond))

      assert returned_state == state
      assert returned_state.operation.mode == :import
    end

    test "cannot start import while exporting - returns error tuple" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_import(state, System.monotonic_time(:millisecond))

      assert returned_state == state
      assert returned_state.operation.mode == :export
    end

    test "cannot start import while importing - returns error tuple" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))

      assert {:error, :operation_in_progress, returned_state} =
               State.start_import(state, System.monotonic_time(:millisecond))

      assert returned_state == state
    end

    test "progress updates noop when not in operation" do
      state = State.new()

      export_result = State.export_progress(state, 5, 10)
      assert export_result == state

      import_result = State.import_progress(state, 5, 10)
      assert import_result == state
    end

    test "finish noops when not in operation" do
      state = State.new()

      export_result = State.finish_export(state, 10)
      assert export_result == state

      import_result = State.complete_import(state, [])
      assert import_result == state
    end

    test "error tuple preserves original state unchanged" do
      original =
        State.new()
        |> State.connect("Folder")
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.export_progress(3, 10)

      assert {:error, :operation_in_progress, returned_state} =
               State.start_import(original, System.monotonic_time(:millisecond))

      assert returned_state == original
      assert returned_state.operation.mode == :export
      assert returned_state.operation.phase == {:running, 3, 10}
    end
  end

  describe "complete workflows" do
    test "full export flow from start to finish" do
      start = System.monotonic_time(:millisecond)

      state =
        State.new()
        |> State.connect("MyFolder")
        |> State.start_export(start)
        |> State.export_progress(0, 10)
        |> State.export_progress(5, 10)
        |> State.export_progress(10, 10)

      Process.sleep(50)

      result = State.finish_export(state, 10)

      assert result.operation.mode == :idle
      assert result.operation.last.type == :export
      assert result.operation.last.count == 10
      assert result.operation.last.duration_ms >= 50
    end

    test "full import flow with mixed results" do
      start = System.monotonic_time(:millisecond)

      state =
        State.new()
        |> State.connect("MyFolder")
        |> State.start_import(start)
        |> State.import_scan_started(5)
        |> State.import_progress(3, 5)
        |> State.import_progress(5, 5)

      results = [
        %{"status" => "success", "note_id" => "n1"},
        %{"status" => "error", "error" => %{"type" => "validation"}},
        %{"status" => "success", "note_id" => "n2"}
      ]

      Process.sleep(50)

      result = State.complete_import(state, results)

      assert result.operation.mode == :idle
      assert result.operation.last.type == :import
      assert result.operation.last.count == 2
      assert result.operation.last.failed == 1
      assert length(result.operation.errors) == 1
    end

    test "can start new operation after export failure" do
      state =
        State.new()
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.fail_export("Network error")

      result = State.start_import(state, System.monotonic_time(:millisecond))

      assert result.operation.mode == :import
      assert result.operation.errors == nil
    end

    test "can start new operation after import failure" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))
        |> State.fail_import("Disk full")

      result = State.start_export(state, System.monotonic_time(:millisecond))

      assert result.operation.mode == :export
      assert result.operation.errors == nil
    end

    test "disconnect preserves operation history" do
      state =
        State.new()
        |> State.connect("Folder")
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(15)
        |> State.disconnect()

      assert state.connection.connected? == false
      assert state.operation.last.count == 15
    end

    test "new operation preserves observer support" do
      state =
        State.new()
        |> State.set_observer_support(true)
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(10)
        |> State.start_import(System.monotonic_time(:millisecond))

      assert state.connection.observer_supported == true
    end

    test "conflicts can be resolved during import" do
      state =
        State.new()
        |> State.start_import(System.monotonic_time(:millisecond))
        |> State.set_id_conflict(%{"server_id" => "s1"})
        |> State.clear_id_conflict()
        |> State.complete_import([])

      assert state.conflict.id_conflict == nil
    end

    test "preview can be used alongside operations" do
      state =
        State.new()
        |> State.set_single_preview("note-1", %{"test" => "data"})
        |> State.start_export(System.monotonic_time(:millisecond))
        |> State.finish_export(5)

      assert state.preview.mode == :single
      assert state.operation.last.count == 5
    end
  end
end
