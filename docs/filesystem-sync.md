# File System Sync Feature

Xeno Notes includes a powerful file system sync feature that allows you to edit your notes in external editors like VS Code, Vim, Neovim, or any text editor of your choice. Changes are automatically or manually synced back to the database.

## Overview

The file system sync feature provides bidirectional synchronization between your Xeno Notes database and a local folder on your computer. This enables a hybrid workflow where you can:

- Use your favorite text editor with all its features (syntax highlighting, extensions, keyboard shortcuts)
- Leverage powerful tools like grep, sed, or git on your notes
- Keep your notes organized in a hierarchical folder structure that mirrors your database
- Have changes automatically sync back to Xeno Notes

## Current Features

### ✅ Export Notes to File System

**Manual Export:**
- Export all notes to a local folder with a single click
- Notes are organized in a directory structure matching your database hierarchy
- Each note is split into two files:
  - `note-name.md` - The note content in Markdown format
  - `note-name.json` - Metadata (tags, data fields, version, timestamps)

**Directory Structure Example:**
```
my-notes/
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

### ✅ Import Changes from File System

**Manual Import:**
- Click "Import Changes" to scan all files and import modifications
- Supports editing markdown content and metadata
- Preserves your directory organization

**Automatic Import (Auto-Sync):**
- Available in Chrome 129+ and Edge 129+ (requires FileSystemObserver API)
- Automatically detects when files are saved in your external editor
- Imports only the changed files (optimized for performance)
- Real-time updates with ~1-2 second delay
- Can be enabled/paused with a single click

### ✅ Conflict Resolution

**Optimistic Locking:**
- Version numbers prevent accidental overwrites
- If a note is modified in the database while you're editing the file, you'll be notified
- Conflict resolution UI helps you choose the correct version

**Error Handling:**
- Clear error messages for invalid JSON, missing files, or permission issues
- Import continues even if individual files fail
- Detailed error reporting showing what succeeded and what failed

### ✅ Persistent Connection

**IndexedDB Storage:**
- Your selected folder is remembered across browser sessions
- No need to reconnect on each visit (unless permissions are revoked)
- Metadata caching for faster operations

## Browser Compatibility

| Feature | Chrome 86+ | Edge 86+ | Chrome 129+ | Edge 129+ | Firefox | Safari |
|---------|------------|----------|-------------|-----------|---------|--------|
| Manual Export | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Manual Import | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Auto-Sync | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |

**Note:** The File System Access API is required for this feature. Firefox and Safari do not currently support it.

## How to Use

### Initial Setup

1. Navigate to `/sync` in Xeno Notes
2. Click "Choose Folder"
3. Select an empty folder or a folder where you want to store your notes
4. Grant read/write permissions when prompted

### Export Your Notes

1. Click "Export All Notes"
2. Wait for the export to complete
3. Open the folder in your favorite editor

### Edit and Sync

**Manual Sync:**
1. Edit `.md` files in your external editor
2. Save your changes
3. Return to Xeno Notes and click "Import Changes"

**Auto-Sync (Chrome 129+/Edge 129+ only):**
1. Click "Enable Auto-Sync"
2. Edit files in your external editor
3. Changes are automatically imported when you save (~1-2 seconds delay)
4. Click "Pause Auto-Sync" to disable

### Understanding the Files

**Markdown Files (`.md`):**
- Contains the note's text content
- Edit freely in any text editor
- Standard Markdown formatting

**Metadata Files (`.json`):**
```json
{
  "id": "uuid-here",
  "name": "Note Name",
  "note_type_id": "uuid-here",
  "tags": ["tag1", "tag2"],
  "data": {
    "custom": "fields"
  },
  "version": 3,
  "inserted_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

**Important:** The `id` and `version` fields are critical for syncing. Don't modify them unless you know what you're doing.

## What's Not Yet Supported

The following features are planned for future releases:

### ⏳ File Operations

- **Creating new notes via file system** - Currently, you can only edit existing notes. New `.md`/`.json` file pairs are not yet imported.
- **Deleting notes via file system** - Deleting files doesn't delete notes from the database yet.
- **Moving/renaming notes** - File path changes aren't synced to the database.
- **Directory operations** - Creating/deleting folders doesn't affect the directory structure in the database.

### ⏳ Advanced Features

- **Bidirectional sync (Database → File System)** - Changes made in Xeno Notes don't automatically update local files yet.
- **Markdown frontmatter support** - Metadata could be embedded in `.md` files instead of separate `.json` files.
- **Binary file support** - Images, PDFs, and other attachments aren't supported yet.
- **Selective sync** - You can't choose specific directories to sync yet (it's all or nothing).
- **Conflict merge tools** - Advanced merge strategies for simultaneous edits aren't available yet.

### ⏳ Performance & Reliability

- **Manual import optimization** - Currently scans all files. Could be optimized to check only changed files (like auto-sync does).
- **Large repository handling** - No special handling for thousands of notes yet (pagination, background workers).
- **Offline queue** - Changes aren't queued when disconnected.
- **Activity log** - No log of sync operations and their outcomes.

## Technical Details

### Architecture

**Backend (Elixir/Phoenix):**
- `Xeno.Sync.Exporter` - Generates file content from database records
- `Xeno.Sync.Importer` - Parses files and updates database records
- `Xeno.Sync` - Public API coordinating export/import operations
- `XenoWeb.SyncLive` - LiveView UI for sync management

**Frontend (TypeScript):**
- `FileSystemHook` - Phoenix LiveView hook managing File System API
- `FileSystemWatcher` - Wrapper for FileSystemObserver API with debouncing
- `DirectoryHandleStore` - IndexedDB persistence for directory handles
- `NoteMetadataStore` - IndexedDB caching for metadata and versions

### Data Flow

**Auto-Sync (FileSystemObserver):**
```
File saved in editor
    ↓
FileSystemObserver detects change
    ↓
Extract changed file paths
    ↓
Read only changed files
    ↓
Send to LiveView
    ↓
Import via Sync.import_change()
    ↓
Update database (with optimistic locking)
    ↓
Flash success message
```

**Manual Import:**
```
User clicks "Import Changes"
    ↓
Recursively scan directory
    ↓
Read all .md/.json file pairs
    ↓
Send all files to LiveView
    ↓
Import each via Sync.import_change()
    ↓
Update database (with optimistic locking)
    ↓
Report successes/failures
```

### Security & Data Integrity

- **Optimistic Locking:** Version numbers prevent conflicting updates
- **Validation:** All file content is validated before database updates
- **Error Recovery:** Partial failures don't stop the entire sync
- **Permissions:** Browser-managed file system permissions (no server-side file access)
- **Data Integrity:** Server validates all changes before persisting

## Troubleshooting

### "Permission denied" errors

**Solution:** Click "Disconnect Folder" and reconnect. Browser permissions may have been revoked.

### "Auto-sync not supported" message

**Solution:** Auto-sync requires Chrome 129+ or Edge 129+. Use manual import if your browser doesn't support it.

### Version conflicts

**Cause:** The note was modified in the database while you were editing the file.

**Solution:** The conflict resolution UI will show you both versions. Choose which one to keep, or merge them manually.

### Import shows "No changes to import"

**Possible causes:**
- All files are already in sync (versions match)
- No `.md` files in the connected folder
- File permissions prevent reading

**Solution:** Check that you saved your files and that they have the correct `.md` extension.

### Files not importing

**Check:**
1. File has `.md` extension
2. Matching `.json` file exists with valid JSON
3. JSON contains required fields: `id`, `version`, `name`
4. UUID in JSON `id` field matches a note in the database

## Roadmap

### Short Term
- Manual import optimization (only scan changed files)
- Better error messages and recovery strategies
- Documentation improvements based on user feedback

### Medium Term
- Support for creating new notes via file system
- Support for deleting notes via file system
- Database → File System sync (reverse direction)
- Improved conflict resolution UI with diff view

### Long Term
- Markdown frontmatter support
- Binary file attachments
- Selective sync (choose which directories)
- Offline sync queue
- Activity log and sync history
- Multi-device sync coordination

## Contributing

Found a bug or have a feature request? Please open an issue on the project repository.

For implementation details and development guidelines, see:
- `planning/editor_integration_implementation.md` - Complete implementation plan and architecture
- Source code in `lib/xeno/sync/` and `assets/js/hooks/file_system_hook.ts`

## Related Documentation

- [File System Access API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API)
- [FileSystemObserver API (Chrome)](https://developer.chrome.com/docs/capabilities/web-apis/file-system-observer)
- Implementation plan: `planning/editor_integration_implementation.md`
