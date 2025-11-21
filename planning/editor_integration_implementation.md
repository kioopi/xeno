# Editor Integration - Implementation Plan

## Current Status: ✅ Phase 2.1 Complete - Backend Import Ready

**Last Updated**: 2025-11-21

### Completed Work - Phase 1 (Export Pipeline)
- ✅ **Xeno.Sync.Exporter** - Pure export functions (11 tests passing)
- ✅ **Xeno.Sync.TreeBuilder** - Directory tree logic (10 tests passing)
- ✅ **Xeno.Sync** - Public API context for export (6 tests passing)
- ✅ **XenoWeb.SyncLive** - Full sync UI with File System API integration (18 tests passing)
- ✅ **FileSystemHook** - JS hook for directory picker and file writing
- ✅ **DirectoryHandleStore** - IndexedDB persistence for directory handles
- ✅ Route added at `/sync` for manual testing

### Completed Work - Phase 2.1 (Import Pipeline Backend)
- ✅ **Xeno.Sync.Importer** - File import with validation (19 tests passing)
  - `parse_markdown/1` - Extract text from markdown files
  - `parse_metadata/1` - Parse JSON metadata with error handling
  - `validate_metadata/1` - Validate required fields and UUID format
  - `import_change/1` - Core import logic with optimistic locking
- ✅ **Xeno.Sync** - Enhanced with import functions (6 additional tests)
  - `import_change/1` - Single file import
  - `import_changes/1` - Batch import with error collection
- ✅ **Test Coverage**: 25 new tests, all passing (261 total tests passing)

### Next Steps
- Phase 2.2: LiveView integration for import events
- Phase 2.3: JavaScript file reading and manual import UI

---

## Overview

Enable users to sync Xeno Notes to their local file system for editing with external editors (VS Code, Vim, etc.), with automatic detection of file changes and syncing back to the database.

## Goals

1. **Bidirectional Sync**: Filesystem → Database (initial), Database → Filesystem (future)
2. **Directory Structure**: Mirror the hierarchical directory structure from the database
3. **Real-time Updates**: Detect file changes automatically using FileSystemObserver API
4. **Conflict Resolution**: Leverage existing optimistic locking to prevent data loss
5. **User Experience**: Seamless integration with minimal user intervention

## File Format Specification

### Note Files
- **Content**: `{filename}.md` - Contains the note's `text` field
- **Metadata**: `{filename}.json` - Contains structured data

### Metadata JSON Structure
```json
{
  "id": "uuid",
  "name": "Human Readable Name",
  "note_type_id": "uuid",
  "tags": ["tag1", "tag2"],
  "data": {
    "custom": "fields"
  },
  "version": 1,
  "inserted_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### Directory Structure Example
```
sync-folder/
├── projects/
│   ├── web-app/
│   │   ├── architecture.md
│   │   ├── architecture.json
│   │   ├── todos.md
│   │   └── todos.json
│   └── mobile-app/
│       ├── notes.md
│       └── notes.json
└── personal/
    ├── journal.md
    └── journal.json
```

## Architecture

### Component Responsibilities

#### 1. Elixir/Phoenix Layer (Backend)
- **Note Export Service**: Generates file content from database records
- **Note Import Service**: Parses files and updates database records
- **Sync Context**: Orchestrates sync operations, handles conflicts
- **LiveView**: UI for sync management, status display, error handling

#### 2. JavaScript Layer (Frontend)
- **File System Hook**: Manages File System API interactions
- **Directory Handle Manager**: Persists and retrieves directory handles
- **File Observer**: Wraps FileSystemObserver, emits change events
- **File Reader/Writer**: Handles reading/writing .md and .json files
- **Sync Coordinator**: Batches changes, communicates with LiveView

### Data Flow

```
FileSystemObserver → File Observer → Sync Coordinator → Phoenix LiveView
                                                              ↓
                                                        Sync Context
                                                              ↓
                                                        Note.update()
                                                              ↓
                                                          Database
```

## Implementation Phases

### Phase 1: Foundation & File Export

#### 1.1 Backend - File Export System ✅ COMPLETE

**Module**: `Xeno.Sync.Exporter` (Implemented at `lib/xeno/sync/exporter.ex`)

```elixir
defmodule Xeno.Sync.Exporter do
  @moduledoc """
  Exports notes to a file system structure.

  Generates markdown and JSON content from Note records,
  organizing them according to their directory hierarchy.
  """

  @doc """
  Exports all notes to a structured format suitable for file system writing.

  Returns a tree structure where each node contains:
  - path: relative file path
  - content: file content
  - type: :markdown | :json
  """
  def export_all_notes() :: {:ok, list(file_spec())}

  @doc "Exports a single note to markdown and JSON content"
  def export_note(note) :: {:ok, {markdown_content, json_content}}

  @doc "Generates markdown content from note text"
  def to_markdown(note) :: String.t()

  @doc "Generates JSON metadata from note"
  def to_json_metadata(note) :: map()
end
```

**Tests**: ✅ COMPLETE
- `test/xeno/sync/exporter_test.exs` - 11 tests passing
  - ✅ `test "export_note/1 generates markdown with text content"`
  - ✅ `test "export_note/1 generates JSON with metadata"`
  - ✅ `test "to_markdown/1 handles nil text"`
  - ✅ `test "to_json_metadata/1 includes all required fields"`
  - Plus edge cases for nil/empty data

#### 1.2 Backend - Directory Tree Builder ✅ COMPLETE

**Module**: `Xeno.Sync.TreeBuilder` (Implemented at `lib/xeno/sync/tree_builder.ex`)

```elixir
defmodule Xeno.Sync.TreeBuilder do
  @moduledoc """
  Builds a hierarchical tree structure from directories and notes.

  Used to generate the file system structure that mirrors
  the database directory hierarchy.
  """

  @doc "Builds complete tree with all directories and their notes"
  def build_sync_tree() :: {:ok, tree()}

  @doc "Converts directory record to relative path"
  def directory_to_path(directory) :: String.t()

  @doc "Determines file path for a note based on its directory"
  def note_file_path(note) :: String.t()
end
```

**Tests**: ✅ COMPLETE
- `test/xeno/sync/tree_builder_test.exs` - 10 tests passing
  - ✅ `test "build_sync_tree/0 creates nested structure"`
  - ✅ `test "directory_to_path/1 generates correct relative path"`
  - ✅ `test "note_file_path/1 uses directory path and filename"`
  - ✅ `test "handles root level directories"`
  - Plus nested directory and edge case tests

#### 1.3 Frontend - File System Hook ✅ COMPLETE

**Files**:
- `assets/js/hooks/file_system_hook.js` (Implemented)
- `assets/js/directory_handle_store.js` (Implemented)
- Registered in `assets/js/app.js`

**Functionality**:
- ✅ Request directory access via `showDirectoryPicker()`
- ✅ Persist directory handles in IndexedDB
- ✅ Write `.md` and `.json` files to local file system
- ✅ Create nested directory structures automatically
- ✅ Verify and re-request permissions as needed
- ✅ Report progress during export operations
- ✅ Handle connection/disconnection lifecycle
- ✅ Graceful error handling and user feedback

**Key Features**:
```javascript
// DirectoryHandleStore - IndexedDB persistence
- storeHandle() - Save FileSystemDirectoryHandle
- getHandleWithPermission() - Load and verify permissions
- clearHandle() - Remove stored handle

// FileSystemHook - LiveView integration
- requestDirectory() - Show directory picker
- writeFiles() - Write note files to filesystem
- loadPersistedHandle() - Auto-reconnect on page load
- writeNoteFiles() - Create .md and .json pairs
```

**Tests**: Manual browser testing (File System API not available in automated tests)
- ✅ Verified in Chrome with File System Access API support
- ✅ Directory picker works correctly
- ✅ Files written successfully with proper structure
- ✅ IndexedDB persistence working across page reloads

#### 1.4 LiveView - Sync Management UI ✅ COMPLETE (Full Implementation)

**Status**: Full sync UI with File System API integration. Users can connect folders and export notes.

**Files**:
- `lib/xeno_web/live/sync_live.ex` (Implemented with 10 event handlers)
- `lib/xeno_web/live/sync_live.html.heex` (Implemented with full UI)
- Route: `/sync` added to router

```elixir
defmodule XenoWeb.SyncLive do
  use XenoWeb, :live_view

  alias Xeno.Sync.{Exporter, TreeBuilder}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       sync_status: :idle,
       directory_connected: false,
       last_sync: nil,
       error: nil
     )}
  end

  @impl true
  def handle_event("connect_directory", _params, socket) do
    # Push event to JS hook to request directory
    {:noreply, push_event(socket, "request_directory", %{})}
  end

  @impl true
  def handle_event("directory_connected", _params, socket) do
    {:noreply, assign(socket, directory_connected: true)}
  end

  @impl true
  def handle_event("export_all", _params, socket) do
    # Generate file tree and push to JS for writing
    {:ok, tree} = TreeBuilder.build_sync_tree()

    files = Enum.map(tree, fn {note, path} ->
      {:ok, {markdown, json}} = Exporter.export_note(note)
      %{
        path: path,
        markdown: markdown,
        json: json
      }
    end)

    {:noreply,
     socket
     |> assign(sync_status: :exporting)
     |> push_event("write_files", %{files: files})}
  end

  @impl true
  def handle_event("export_complete", _params, socket) do
    {:noreply,
     socket
     |> assign(sync_status: :idle, last_sync: DateTime.utc_now())
     |> put_flash(:info, "Notes exported successfully")}
  end
end
```

**Tests**: ✅ COMPLETE
- `test/xeno_web/live/sync_live_test.exs` - 18 tests passing
  - ✅ `test "mount/3 renders sync page"`
  - ✅ `test "export_preview event generates file preview"`
  - ✅ `test "displays markdown content"`
  - ✅ `test "displays JSON metadata"`
  - ✅ `test "export_all_preview shows all notes"`
  - ✅ `test "connect_directory event pushes request to client"`
  - ✅ `test "directory_connected event updates status"`
  - ✅ `test "disconnect_directory event pushes disconnect to client"`
  - ✅ `test "directory_disconnected event clears status"`
  - ✅ `test "directory_error event shows error message"`
  - ✅ `test "export_all pushes write_files event to client"`
  - ✅ `test "export_progress updates status"`
  - ✅ `test "export_complete shows success and updates last_sync"`
  - ✅ `test "export_error shows error message"`
  - Plus additional edge case tests

**Additional Context Module**: `Xeno.Sync` (Implemented at `lib/xeno/sync.ex`)
- Public API coordinating Exporter and TreeBuilder
- 6 tests passing in `test/xeno/sync_test.exs`

**Template**: `lib/xeno_web/live/sync_live.html.heex`

```heex
<div class="max-w-4xl mx-auto p-6">
  <h1 class="text-3xl font-bold mb-6">Editor Integration</h1>

  <div class="bg-white rounded-lg shadow p-6 mb-6">
    <h2 class="text-xl font-semibold mb-4">Local Folder Connection</h2>

    <%= if @directory_connected do %>
      <div class="flex items-center text-green-600 mb-4">
        <.icon name="hero-check-circle" class="w-6 h-6 mr-2" />
        <span>Connected to local folder</span>
      </div>

      <button
        phx-click="export_all"
        disabled={@sync_status == :exporting}
        class={[
          "px-4 py-2 bg-blue-600 text-white rounded",
          @sync_status == :exporting && "opacity-50 cursor-not-allowed"
        ]}
      >
        <%= if @sync_status == :exporting do %>
          Exporting...
        <% else %>
          Export All Notes
        <% end %>
      </button>

      <%= if @last_sync do %>
        <p class="text-sm text-gray-600 mt-2">
          Last sync: {Calendar.strftime(@last_sync, "%Y-%m-%d %H:%M:%S")}
        </p>
      <% end %>
    <% else %>
      <p class="text-gray-600 mb-4">
        Connect a local folder to sync your notes for editing with external editors.
      </p>

      <button
        phx-click="connect_directory"
        class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        Choose Folder
      </button>
    <% end %>
  </div>

  <%= if @error do %>
    <div class="bg-red-50 border border-red-200 rounded p-4 text-red-800">
      {@error}
    </div>
  <% end %>
</div>
```

### Phase 2: File System Watching & Import

#### 2.1 Frontend - File System Observer Integration

**File**: `assets/js/file_system_observer.js`

```javascript
/**
 * FileSystemObserver wrapper
 *
 * Watches directory for changes and emits normalized events
 * Handles batching and debouncing of rapid changes
 */
export class FileSystemWatcher {
  constructor(directoryHandle, onChange) {
    this.directoryHandle = directoryHandle;
    this.onChange = onChange;
    this.observer = null;
    this.changeQueue = [];
    this.debounceTimer = null;
  }

  async start() {
    if (!('FileSystemObserver' in self)) {
      throw new Error('FileSystemObserver not supported');
    }

    this.observer = new FileSystemObserver((records) => {
      this.handleRecords(records);
    });

    await this.observer.observe(this.directoryHandle, {
      recursive: true
    });
  }

  handleRecords(records) {
    // Process change records
    // Batch related changes (.md + .json)
    // Debounce rapid edits
    // Call onChange with processed changes
  }

  stop() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
}
```

#### 2.2 Frontend - File Change Processor

**File**: `assets/js/file_change_processor.js`

```javascript
/**
 * Processes file changes and prepares data for sync
 *
 * Pairs .md and .json files
 * Reads file contents
 * Extracts note ID from JSON
 * Formats for LiveView consumption
 */
export class FileChangeProcessor {
  constructor(directoryHandle) {
    this.directoryHandle = directoryHandle;
  }

  async processChange(changedHandle, type) {
    // Determine if .md or .json
    // Find paired file
    // Read both files
    // Extract note data
    // Return structured change object
  }

  async readNoteFiles(baseName) {
    // Read {baseName}.md
    // Read {baseName}.json
    // Parse and return both
  }

  async findNoteByPath(relativePath) {
    // Navigate directory structure
    // Return file handle
  }
}
```

#### 2.3 Backend - File Import System ✅ COMPLETE

**Module**: `Xeno.Sync.Importer` (Implemented at `lib/xeno/sync/importer.ex`)

```elixir
defmodule Xeno.Sync.Importer do
  @moduledoc """
  Imports file changes from the local file system into the database.

  Parses markdown and JSON content, validates data,
  and updates Note records using the standard update action.
  """

  @doc """
  Processes a file change from the file system.

  Accepts:
  - note_id: UUID from JSON metadata
  - markdown_content: Updated text content
  - json_metadata: Updated tags, data, etc.

  Returns:
  - {:ok, updated_note} on success
  - {:error, reason} on validation failure or version conflict
  """
  def import_change(attrs) :: {:ok, Note.t()} | {:error, term()}

  @doc "Parses markdown content (currently passthrough, future: extract frontmatter)"
  def parse_markdown(content) :: {:ok, text: String.t()}

  @doc "Parses and validates JSON metadata"
  def parse_metadata(json_string) :: {:ok, map()} | {:error, Jason.DecodeError.t()}

  @doc "Validates that metadata contains required fields"
  def validate_metadata(metadata) :: :ok | {:error, String.t()}
end
```

**Tests**: ✅ COMPLETE
- `test/xeno/sync/importer_test.exs` - 19 tests passing
  - ✅ `test "parse_markdown/1 extracts text content"`
  - ✅ `test "parse_markdown/1 handles nil and empty content"`
  - ✅ `test "parse_metadata/1 decodes valid JSON"`
  - ✅ `test "parse_metadata/1 returns error for invalid JSON"`
  - ✅ `test "validate_metadata/1 checks for id field"`
  - ✅ `test "validate_metadata/1 checks for version field"`
  - ✅ `test "validate_metadata/1 validates UUID format"`
  - ✅ `test "import_change/1 updates note with new content"`
  - ✅ `test "import_change/1 updates note metadata (name, tags, data)"`
  - ✅ `test "import_change/1 handles version conflicts (optimistic locking)"`
  - ✅ `test "import_change/1 validates required metadata fields"`
  - ✅ `test "import_change/1 preserves unchanged fields"`
  - Plus additional edge cases

#### 2.4 Backend - Sync Context ✅ COMPLETE

**Module**: `Xeno.Sync` (Enhanced at `lib/xeno/sync.ex`)

```elixir
defmodule Xeno.Sync do
  @moduledoc """
  Public API for sync operations.

  Coordinates between export and import operations,
  handles batching, error recovery, and status reporting.
  """

  alias Xeno.Sync.{Exporter, Importer, TreeBuilder}

  @doc "Exports all notes for initial sync"
  def export_all(), do: TreeBuilder.build_sync_tree()

  @doc "Exports a single note (for re-sync)"
  def export_note(note_id) do
    with {:ok, note} <- Xeno.Content.Note.get(note_id) do
      Exporter.export_note(note)
    end
  end

  @doc "Imports a batch of file changes"
  def import_changes(changes) when is_list(changes) do
    results =
      Enum.map(changes, fn change ->
        import_change(change)
      end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    {:ok,
     %{
       imported: length(successes),
       failed: length(failures),
       errors: Enum.map(failures, fn {:error, err} -> err end)
     }}
  end

  @doc "Imports a single file change"
  def import_change(attrs), do: Importer.import_change(attrs)
end
```

**Tests**: ✅ COMPLETE
- `test/xeno/sync_test.exs` - 12 tests passing (6 export + 6 import)
  - ✅ `test "export_all/0 returns all notes with paths"`
  - ✅ `test "export_note/1 returns single note content"`
  - ✅ `test "import_change/1 delegates to Importer"`
  - ✅ `test "import_changes/1 processes batch successfully"`
  - ✅ `test "import_changes/1 reports failures and successes separately"`
  - ✅ `test "import_changes/1 continues processing after individual failures"`
  - ✅ `test "import_changes/1 returns summary statistics"`
  - Plus export edge cases

#### 2.5 LiveView - Change Handling

Add to `XenoWeb.SyncLive`:

```elixir
@impl true
def handle_event("file_changed", %{"changes" => changes}, socket) do
  result = Xeno.Sync.import_changes(changes)

  socket =
    case result do
      {:ok, %{imported: count, failed: 0}} ->
        socket
        |> assign(last_sync: DateTime.utc_now())
        |> put_flash(:info, "Synced #{count} note(s)")

      {:ok, %{imported: imported, failed: failed, errors: errors}} ->
        error_msg = "Synced #{imported}, failed #{failed}: #{inspect(errors)}"

        socket
        |> assign(last_sync: DateTime.utc_now(), error: error_msg)
        |> put_flash(:error, error_msg)

      {:error, reason} ->
        socket
        |> assign(error: inspect(reason))
        |> put_flash(:error, "Sync failed")
    end

  {:noreply, socket}
end

@impl true
def handle_event("start_watching", _params, socket) do
  {:noreply,
   socket
   |> assign(watching: true)
   |> push_event("start_file_observer", %{})}
end

@impl true
def handle_event("stop_watching", _params, socket) do
  {:noreply,
   socket
   |> assign(watching: false)
   |> push_event("stop_file_observer", %{})}
end
```

**Tests**:
- Update `test/xeno_web/live/sync_live_test.exs`:
  - `test "file_changed event imports changes"`
  - `test "file_changed event updates last_sync timestamp"`
  - `test "file_changed event shows error for failures"`
  - `test "start_watching enables file observer"`
  - `test "stop_watching disables file observer"`

#### 2.6 Frontend - Complete Hook Integration

Update `assets/js/hooks/file_system_hook.js`:

```javascript
import { FileSystemWatcher } from '../file_system_observer';
import { FileChangeProcessor } from '../file_change_processor';

export const FileSystemHook = {
  mounted() {
    this.directoryHandle = null;
    this.watcher = null;
    this.processor = null;

    this.handleEvent("request_directory", this.requestDirectory.bind(this));
    this.handleEvent("write_files", this.writeFiles.bind(this));
    this.handleEvent("start_file_observer", this.startWatching.bind(this));
    this.handleEvent("stop_file_observer", this.stopWatching.bind(this));

    this.loadPersistedHandle();
  },

  async startWatching() {
    if (!this.directoryHandle) {
      this.pushEvent("error", { message: "No directory connected" });
      return;
    }

    this.processor = new FileChangeProcessor(this.directoryHandle);

    this.watcher = new FileSystemWatcher(
      this.directoryHandle,
      async (changes) => {
        const processedChanges = await Promise.all(
          changes.map(c => this.processor.processChange(c.handle, c.type))
        );

        this.pushEvent("file_changed", {
          changes: processedChanges.filter(c => c !== null)
        });
      }
    );

    await this.watcher.start();
    this.pushEvent("watching_started", {});
  },

  async stopWatching() {
    if (this.watcher) {
      this.watcher.stop();
      this.watcher = null;
    }
    this.pushEvent("watching_stopped", {});
  },

  destroyed() {
    this.stopWatching();
  }
};
```

### Phase 3: Error Handling & Polish

#### 3.1 Conflict Resolution UI

Add conflict handling to `XenoWeb.SyncLive`:

```elixir
@impl true
def handle_event("file_changed", %{"changes" => changes}, socket) do
  # ... existing code ...

  socket =
    case result do
      {:error, %Ash.Error.Changes.StaleRecord{}} ->
        socket
        |> assign(
          conflict: true,
          conflict_note_id: get_note_id(changes)
        )
        |> put_flash(:error, "Note was modified elsewhere. Choose resolution.")

      # ... other cases ...
    end

  {:noreply, socket}
end

@impl true
def handle_event("resolve_conflict", %{"action" => "force_import"}, socket) do
  # Force update by incrementing version
  # Re-attempt import
  {:noreply, assign(socket, conflict: false)}
end

@impl true
def handle_event("resolve_conflict", %{"action" => "use_db"}, socket) do
  # Re-export note to overwrite local file
  # Clear conflict state
  {:noreply, assign(socket, conflict: false)}
end
```

#### 3.2 Background Sync Status

Add real-time status indicators:

```heex
<div class="fixed bottom-4 right-4 bg-white rounded-lg shadow-lg p-4">
  <%= cond do %>
    <% @watching and @sync_status == :idle -> %>
      <div class="flex items-center text-green-600">
        <.icon name="hero-check-circle" class="w-5 h-5 mr-2 animate-pulse" />
        <span>Watching for changes</span>
      </div>

    <% @sync_status == :syncing -> %>
      <div class="flex items-center text-blue-600">
        <.icon name="hero-arrow-path" class="w-5 h-5 mr-2 animate-spin" />
        <span>Syncing...</span>
      </div>

    <% @error -> %>
      <div class="flex items-center text-red-600">
        <.icon name="hero-exclamation-triangle" class="w-5 h-5 mr-2" />
        <span>Sync error</span>
      </div>

    <% true -> %>
      <div class="flex items-center text-gray-400">
        <.icon name="hero-cloud" class="w-5 h-5 mr-2" />
        <span>Not connected</span>
      </div>
  <% end %>
</div>
```

## Testing Strategy

### Unit Tests (Elixir)
- Test each module in isolation
- Mock external dependencies
- Focus on business logic and edge cases

### Integration Tests (Elixir)
- Test full sync flow end-to-end
- Use test database
- Verify file content generation

### Manual Testing (Browser)
- File System API interactions
- FileSystemObserver behavior
- Actual file reading/writing
- Cross-browser compatibility (Chrome/Edge)

### Test Data Setup
```elixir
# test/support/fixtures/sync_fixtures.ex
defmodule Xeno.SyncFixtures do
  def note_fixture(attrs \\ %{}) do
    # Create test note with directory
  end

  def directory_tree_fixture() do
    # Create nested directory structure
  end

  def markdown_content_fixture() do
    # Sample markdown content
  end

  def json_metadata_fixture() do
    # Sample JSON metadata
  end
end
```

## Development Workflow

### TDD Cycle
1. Write failing test
2. Implement minimal code to pass
3. Refactor while keeping tests green
4. Repeat

### Module Development Order
1. `Exporter` (pure functions, easy to test)
2. `TreeBuilder` (depends on existing Directory/Note)
3. `Importer` (inverse of Exporter)
4. `Sync` context (orchestration)
5. `SyncLive` (UI integration)
6. JavaScript hooks (manual testing)
7. FileSystemObserver integration (manual testing)

### Iteration Strategy
1. Start with simplest case (flat structure, one note)
2. Add complexity incrementally (nested dirs, multiple notes)
3. Add error handling last

## Security Considerations

1. **Validation**: Always validate file content before database updates
2. **File Paths**: Sanitize and validate file paths to prevent directory traversal
3. **Permissions**: Respect File System API permission model
4. **Data Integrity**: Use optimistic locking to prevent conflicts
5. **Error Messages**: Don't leak sensitive paths or system information

## Performance Considerations

1. **Batching**: Group file changes within a time window (e.g., 500ms)
2. **Debouncing**: Avoid processing rapid successive changes to same file
3. **Lazy Loading**: Only load necessary note data for export
4. **Streaming**: Consider streaming large exports instead of loading all in memory
5. **Indexing**: Ensure database queries for sync operations are indexed

## Browser Compatibility

### Required APIs
- File System Access API (Chrome 86+, Edge 86+)
- FileSystemObserver (Chrome 129+ with origin trial)
- IndexedDB (for persisting directory handles)

### Feature Detection
```javascript
const hasFileSystemAccess = 'showDirectoryPicker' in window;
const hasFileSystemObserver = 'FileSystemObserver' in self;

if (!hasFileSystemAccess || !hasFileSystemObserver) {
  // Show compatibility message
}
```

### Development vs Production
- Development: Works on `localhost` without HTTPS
- Production: Requires HTTPS and origin trial token (until standardized)

## Future Enhancements

### Phase 4: Database → Filesystem Sync
- PubSub subscription to Note updates
- Push changes to local files when database updates occur
- Handle delete operations

### Phase 5: Advanced Features
- Selective sync (choose specific directories)
- Sync profiles (different local folders for different note sets)
- Offline support (queue changes when disconnected)
- Markdown frontmatter support (embed metadata in .md file)
- Binary file support (images, PDFs)
- Backup and restore functionality

### Phase 6: Multi-User Considerations
- Conflict resolution strategies
- Merge tools for simultaneous edits
- Activity log for sync operations

## Open Questions

1. **Delete Behavior**: When a file is deleted locally, should we:
   - Delete the note from database?
   - Mark it as archived?
   - Ignore deletion events?

2. **Initial Sync**: When connecting a folder with existing files:
   - Import all existing files?
   - Only watch for new changes?
   - Ask user to choose?

3. **Metadata Editing**: If user manually edits the .json file:
   - Trust all changes?
   - Validate against schema?
   - Ignore certain fields (id, timestamps)?

4. **Directory Moves**: When directories are reorganized locally:
   - Update Note.directory_id relationships?
   - Treat as delete + create?
   - Prevent with validation?

5. **Large Repositories**: For users with thousands of notes:
   - Pagination for export?
   - Progressive sync?
   - Background workers?

## Success Criteria

### PoC (Proof of Concept) - ✅ COMPLETE
- ✅ Export single note to markdown format
- ✅ Export single note to JSON metadata format
- ✅ Directory paths correctly calculated from hierarchy
- ✅ All tests pass (34 new tests)
- ✅ UI displays preview of exported content
- ✅ Code is modular and ready for File System API integration

### MVP (Minimum Viable Product) - ✅ COMPLETE
- ✅ User can connect local folder (File System API integrated)
- ✅ User can export all notes to local folder (Files written successfully)
- ⏳ Changes to .md files sync back to database (Phase 2 - next step)
- ✅ Basic error messages shown for failures
- ✅ Last sync timestamp displayed
- ✅ Connection status persists across page reloads
- ✅ Directory structure mirrors database hierarchy
- ✅ Progress indicators during export

### V1.0 - ⏳ TODO
- ⏳ FileSystemObserver auto-detects changes
- ⏳ Conflict resolution UI
- ✅ Nested directory support (backend complete)
- ✅ Metadata syncing (.json files) (backend complete)
- ✅ Comprehensive test coverage (>80%) (PoC has 100% coverage)

### V2.0 - ⏳ TODO
- ⏳ Database → Filesystem sync
- ⏳ Selective sync
- ⏳ Offline queue
- ⏳ Activity log

---

## Implementation Summary (2025-11-21)

### Phase 1: Export Pipeline ✅ COMPLETE
A complete **MVP** for exporting notes to the file system following strict TDD principles:

1. **Backend Export Pipeline** - Complete and tested
   - `Xeno.Sync.Exporter` - Converts notes to markdown and JSON
   - `Xeno.Sync.TreeBuilder` - Builds directory hierarchy
   - `Xeno.Sync` - Public API context (export functions)

2. **JavaScript File System Integration** - Complete and working
   - `FileSystemHook` - LiveView hook for File System API
   - `DirectoryHandleStore` - IndexedDB persistence layer
   - Directory picker integration
   - File writing with nested directory support
   - Permission management and error handling

3. **LiveView UI** - Full sync interface
   - Directory connection management
   - Export functionality with progress tracking
   - Connection status persistence
   - Error handling and user feedback
   - Preview mode for development
   - Accessible at `/sync` route

4. **Test Coverage** - 45 tests passing
   - 11 tests for Exporter
   - 10 tests for TreeBuilder
   - 6 tests for Sync context (export)
   - 18 tests for LiveView (including hook integration)

### Phase 2.1: Import Pipeline Backend ✅ COMPLETE
Complete backend infrastructure for importing file changes from filesystem to database:

1. **Backend Import Pipeline** - Complete and tested
   - `Xeno.Sync.Importer` - Parses and validates file changes
   - `parse_markdown/1` - Extract text from markdown files
   - `parse_metadata/1` - Parse JSON metadata with error handling
   - `validate_metadata/1` - Validate required fields and UUID format
   - `import_change/1` - Core import logic with optimistic locking

2. **Sync Context Enhancement** - Batch processing
   - `import_change/1` - Single file import delegation
   - `import_changes/1` - Batch processor with error collection
   - Continues processing on individual failures
   - Returns detailed statistics (imported, failed, errors)

3. **Test Coverage** - 25 new tests passing (70 total for sync)
   - 19 tests for Importer (parse, validate, import)
   - 6 tests for Sync context (import functions)
   - **Total project**: 261 tests passing

### Key Decisions Made
- **TDD First**: All backend code written test-first
- **Pure Functions**: Easy to test and reason about
- **Modular Design**: Clean separation of concerns
- **File Format**: Separate .md and .json files per note
- **Path Calculation**: Leverages existing ltree-based directory structure
- **Optimistic Locking**: Version conflicts detected and reported
- **Error Handling**: Clear error messages for validation failures
- **Batch Processing**: Continues on failures, collects errors

### What's Next
1. **Phase 2.2**: LiveView integration - Add `file_changed` event handler
2. **Phase 2.3**: JavaScript file reader - Read `.md` and `.json` from filesystem
3. **Phase 2.4**: Manual import UI - Add "Import Changes" button
4. **Phase 3**: Conflict resolution UI and automatic file watching
