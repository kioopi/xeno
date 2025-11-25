# Testing Strategy for Filesystem Sync

## Overview

This document outlines the comprehensive testing strategy for the Filesystem Sync feature, which enables bidirectional synchronization between the Xeno note database and local filesystem using the browser's File System Access API.

**Last Updated**: 2024-11-24

---

## Testing Architecture

The sync feature uses a multi-layered testing approach due to browser security restrictions:

```
┌─────────────────────────────────────────────────────────┐
│                   Manual Testing                         │
│  (File System Access API, real browser interaction)     │
└─────────────────────────────────────────────────────────┘
                           ↑
┌─────────────────────────────────────────────────────────┐
│              LiveView Feature Tests                      │
│    (UI state, server-side logic, PhoenixTest)           │
└─────────────────────────────────────────────────────────┘
                           ↑
┌─────────────────────────────────────────────────────────┐
│            TypeScript Unit Tests                         │
│  (Hook logic, IndexedDB, mocked File System API)        │
└─────────────────────────────────────────────────────────┘
```

---

## 1. TypeScript Unit Tests (47 tests)

**Location**: `assets/js/**/*.test.ts`

**Purpose**: Test client-side logic without actual File System Access API

**Coverage**:
- FileSystemHook event handlers (24 tests)
- DirectoryHandleStore operations (10 tests)
- NoteMetadataStore IndexedDB operations (8+ tests)
- JsonFileManager, ImportErrorHandler, etc.

**Technology Stack**:
- **Vitest** - Fast unit test runner
- **fake-indexeddb** - Mock IndexedDB for testing
- **Vi mocks** - Mock LiveView push events

**Running Tests**:
```bash
cd assets
npm test
```

### What Can Be Tested

✅ **Testable with Unit Tests**:
- Event handler logic (requestDirectory, disconnectDirectory, writeFiles, scanFiles)
- IndexedDB storage and retrieval
- Permission checking logic (mocked)
- Error handling for missing API support
- Progress event emission
- Import result processing and IndexedDB updates
- JSON file parsing and validation
- Version conflict detection
- Error message formatting

### What Cannot Be Tested

❌ **Cannot Test (Security Restrictions)**:
- Actual `showDirectoryPicker()` user interaction
- Real File System Access API operations
- Browser permission dialogs
- File handle serialization/deserialization
- Actual file reads/writes to disk

### Example Test Structure

```typescript
describe('FileSystemHook', () => {
  let hook: any;
  let mockPushEvent: any;

  beforeEach(async () => {
    await noteMetadataStore.clear();
    mockPushEvent = vi.fn();

    hook = {
      ...FileSystemHook,
      pushEvent: mockPushEvent,
      handleStore: {
        storeHandle: vi.fn(),
        verifyPermission: vi.fn()
      }
    };
  });

  describe('writeFiles', () => {
    it('pushes error when no directory connected', async () => {
      hook.directoryHandle = null;
      await hook.writeFiles({ files: [] });

      expect(mockPushEvent).toHaveBeenCalledWith('export_error', {
        message: 'No directory connected'
      });
    });
  });
});
```

---

## 2. LiveView Feature Tests (14 tests)

**Location**: `test/xeno_web/features/sync_live_test.exs`

**Purpose**: Test server-side LiveView logic and UI state management

**Coverage**:
- Initial page load and UI elements
- Button visibility based on connection state
- Export preview functionality
- Error container existence
- Accessibility and semantic structure
- Flash messages

**Technology Stack**:
- **PhoenixTest** - LiveView integration testing
- **Sandbox mode** - Isolated database transactions

**Running Tests**:
```bash
mix test test/xeno_web/features/sync_live_test.exs
```

### What Can Be Tested

✅ **Testable with Feature Tests**:
- UI element visibility (buttons, messages, containers)
- Conditional rendering based on assigns
- Browser compatibility warnings
- Export preview buttons
- Error container structure
- Page semantic structure
- Server-side event handling
- LiveView mount and update logic

### What Cannot Be Tested

❌ **Cannot Test (Client-Side API)**:
- Actual directory picker interaction
- Real file system operations
- JavaScript hook execution
- IndexedDB operations
- File System Access API

### Example Test Structure

```elixir
defmodule XenoWeb.Features.SyncLiveTest do
  use XenoWeb.FeatureCase, async: false

  describe "initial page load" do
    test "shows connect button when not connected" do
      build_conn()
      |> visit("/sync")
      |> assert_has("#connect-directory-btn", text: "Choose Folder")
    end

    test "does not show export/import buttons when not connected" do
      session = build_conn() |> visit("/sync")

      refute_has(session, "#export-all-btn")
      refute_has(session, "#import-btn")
    end
  end
end
```

---

## 3. Manual Testing (Required)

**Location**: `planning/manual_testing_checklist.md`

**Purpose**: Test functionality that cannot be automated due to browser security

**Coverage**:
- Actual directory picker interaction
- Real file system read/write operations
- Permission grant/revoke flows
- File content verification
- Cross-session persistence
- Import/export round-trips
- Error recovery scenarios

**Running Tests**: Follow checklist at http://localhost:4000/sync

### Critical Manual Test Scenarios

1. **Directory Connection**
   - Browser shows native picker dialog
   - User can select folder
   - Permission is granted properly

2. **Export to Filesystem**
   - Files are written to disk
   - Directory structure is created
   - Content matches database

3. **Import from Filesystem**
   - Changes detected correctly
   - Files parsed successfully
   - Database updated properly

4. **Persistence**
   - Handle survives page reload
   - Permissions persist across sessions

5. **Error Handling**
   - Permission denied scenarios
   - Invalid file format handling
   - Network/disk errors

---

## Test Execution Workflow

### During Development

```bash
# Run TypeScript tests in watch mode
cd assets && npm test

# Run Elixir tests
mix test

# Run specific test file
mix test test/xeno_web/features/sync_live_test.exs
```

### Before Committing

```bash
# Run all automated tests
mix precommit

# This includes:
# - mix format
# - mix credo
# - mix test
# - cd assets && npm test -- --run
```

### Before Releasing

1. Run all automated tests (TypeScript + Elixir)
2. Execute full manual testing checklist
3. Document any issues or observations
4. Get sign-off from QA

---

## Coverage Analysis

| Component | Unit Tests | Feature Tests | Manual Tests | Total Coverage |
|-----------|-----------|---------------|--------------|----------------|
| FileSystemHook | 24 | - | Required | High |
| DirectoryHandleStore | 10 | - | Required | High |
| NoteMetadataStore | 8 | - | - | High |
| SyncLive UI | - | 14 | Required | Medium-High |
| File System API | - | - | Required | Manual Only |
| Import/Export Logic | 5+ | - | Required | High |

**Total Automated Tests**: 61 (47 TypeScript + 14 Elixir)

---

## Known Limitations

### Browser Compatibility
- File System Access API only works in Chrome 86+, Edge 86+
- Safari and Firefox do not support this API
- Requires HTTPS in production (localhost OK for dev)

### Testing Limitations
- Cannot automate directory picker (requires user gesture)
- Cannot mock File System Access API completely
- Must rely on manual testing for full integration

### Workarounds
- Comprehensive unit test coverage with mocks
- Feature tests for UI state
- Detailed manual testing checklist
- Clear documentation of test boundaries

---

## Future Improvements

### Potential Enhancements
1. **Visual regression testing** for UI components
2. **E2E tests** with Playwright (limited by API restrictions)
3. **Performance testing** for large note collections
4. **Cross-browser compatibility testing** (when APIs available)
5. **Automated manual test execution** (using browser extensions)

### Test Expansion Areas
1. Concurrent export/import operations
2. Large file handling (>10MB notes)
3. Network interruption scenarios
4. Browser crash recovery
5. Multi-tab synchronization

---

## Continuous Integration

### CI Pipeline (Future)

```yaml
# .github/workflows/test.yml (example)
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      # Elixir tests
      - name: Run Elixir tests
        run: mix test

      # TypeScript tests
      - name: Run TypeScript tests
        run: cd assets && npm ci && npm test -- --run

      # Manual test reminder
      - name: Manual test reminder
        run: echo "⚠️ Remember to run manual tests from checklist"
```

---

## Conclusion

The filesystem sync feature employs a pragmatic testing strategy that maximizes automated test coverage while acknowledging browser security restrictions. The combination of:

- **47 TypeScript unit tests** for client-side logic
- **14 LiveView feature tests** for server-side logic and UI
- **Comprehensive manual testing checklist** for File System Access API

...provides robust quality assurance for this critical feature.

**Key Principle**: Test what you can automate, document what you must verify manually.

---

## References

- [File System Access API Spec](https://wicg.github.io/file-system-access/)
- [Vitest Documentation](https://vitest.dev/)
- [PhoenixTest Documentation](https://hexdocs.pm/phoenix_test/)
- [Manual Testing Checklist](../planning/manual_testing_checklist.md)
