import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { FileSystemHook } from './file_system_hook';
import { noteMetadataStore } from '../stores/note_metadata_store';

describe('FileSystemHook', () => {
  let hook: any;
  let mockPushEvent: any;
  let mockHandleEvent: any;

  beforeEach(async () => {
    await noteMetadataStore.clear();

    mockPushEvent = vi.fn();
    mockHandleEvent = vi.fn();

    hook = {
      ...FileSystemHook,
      pushEvent: mockPushEvent,
      handleEvent: mockHandleEvent,
      directoryHandle: null,
      handleStore: {
        storeHandle: vi.fn(),
        getHandleWithPermission: vi.fn(),
        verifyPermission: vi.fn(),
        clearHandle: vi.fn()
      }
    };
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('requestDirectory', () => {
    it('pushes error event when File System Access API not supported', async () => {
      const originalShowDirectoryPicker = (global as any).showDirectoryPicker;
      delete (global as any).showDirectoryPicker;

      await hook.requestDirectory();

      expect(mockPushEvent).toHaveBeenCalledWith('directory_error', {
        message: expect.stringContaining('not supported')
      });

      (global as any).showDirectoryPicker = originalShowDirectoryPicker;
    });

    it('does not push event when user cancels directory selection', async () => {
      const abortError = new Error('User cancelled');
      abortError.name = 'AbortError';

      (global as any).showDirectoryPicker = vi.fn().mockRejectedValue(abortError);

      await hook.requestDirectory();

      expect(mockPushEvent).not.toHaveBeenCalled();
    });

    it('pushes error event on directory selection failure', async () => {
      const error = new Error('Permission denied');
      (global as any).showDirectoryPicker = vi.fn().mockRejectedValue(error);

      await hook.requestDirectory();

      expect(mockPushEvent).toHaveBeenCalledWith('directory_error', {
        message: 'Permission denied'
      });
    });

    it('stores handle and pushes success event on successful selection', async () => {
      const mockHandle = { name: 'test-folder' };
      (global as any).showDirectoryPicker = vi.fn().mockResolvedValue(mockHandle);

      await hook.requestDirectory();

      expect(hook.handleStore.storeHandle).toHaveBeenCalledWith(mockHandle);
      expect(mockPushEvent).toHaveBeenCalledWith('directory_connected', {
        name: 'test-folder'
      });
      expect(hook.directoryHandle).toBe(mockHandle);
    });
  });

  describe('disconnectDirectory', () => {
    it('clears handle and pushes disconnected event', async () => {
      hook.directoryHandle = { name: 'test-folder' };

      await hook.disconnectDirectory();

      expect(hook.handleStore.clearHandle).toHaveBeenCalled();
      expect(hook.directoryHandle).toBeNull();
      expect(mockPushEvent).toHaveBeenCalledWith('directory_disconnected', {});
    });

    it('pushes error event when clear fails', async () => {
      hook.handleStore.clearHandle.mockRejectedValue(new Error('Clear failed'));

      await hook.disconnectDirectory();

      expect(mockPushEvent).toHaveBeenCalledWith('directory_error', {
        message: 'Failed to disconnect directory'
      });
    });
  });

  describe('writeFiles', () => {
    it('pushes error when no directory connected', async () => {
      hook.directoryHandle = null;

      await hook.writeFiles({ files: [] });

      expect(mockPushEvent).toHaveBeenCalledWith('export_error', {
        message: 'No directory connected'
      });
    });

    it('pushes error when permission denied', async () => {
      hook.directoryHandle = { name: 'test-folder' };
      hook.handleStore.verifyPermission.mockResolvedValue(false);

      await hook.writeFiles({ files: [] });

      expect(mockPushEvent).toHaveBeenCalledWith('export_error', {
        message: expect.stringContaining('Permission denied')
      });
      expect(hook.handleStore.clearHandle).toHaveBeenCalled();
      expect(hook.directoryHandle).toBeNull();
    });

    it('pushes progress events during file writing', async () => {
      hook.directoryHandle = { name: 'test-folder' };
      hook.handleStore.verifyPermission.mockResolvedValue(true);
      hook.writeNoteFiles = vi.fn().mockResolvedValue(undefined);

      const files = [
        { path: 'note1.md', markdown: 'content1', json: '{}' },
        { path: 'note2.md', markdown: 'content2', json: '{}' }
      ];

      await hook.writeFiles({ files });

      expect(mockPushEvent).toHaveBeenCalledWith('export_progress', {
        current: 1,
        total: 2
      });
      expect(mockPushEvent).toHaveBeenCalledWith('export_progress', {
        current: 2,
        total: 2
      });
      expect(mockPushEvent).toHaveBeenCalledWith('export_complete', {
        count: 2
      });
    });

    it('pushes error event on write failure', async () => {
      hook.directoryHandle = { name: 'test-folder' };
      hook.handleStore.verifyPermission.mockResolvedValue(true);
      hook.writeNoteFiles = vi.fn().mockRejectedValue(new Error('Write failed'));

      const files = [{ path: 'note1.md', markdown: 'content', json: '{}' }];

      await hook.writeFiles({ files });

      expect(mockPushEvent).toHaveBeenCalledWith('export_error', {
        message: 'Write failed'
      });
    });
  });

  describe('scanFiles', () => {
    it('pushes error when no directory connected', async () => {
      hook.directoryHandle = null;

      await hook.scanFiles();

      expect(mockPushEvent).toHaveBeenCalledWith('import_error', {
        message: 'No directory connected'
      });
    });

    it('pushes error when permission denied', async () => {
      hook.directoryHandle = { name: 'test-folder' };
      hook.handleStore.verifyPermission.mockResolvedValue(false);

      await hook.scanFiles();

      expect(mockPushEvent).toHaveBeenCalledWith('import_error', {
        message: expect.stringContaining('Permission denied')
      });
    });

    it('scans for changes and pushes import_files event', async () => {
      hook.directoryHandle = { name: 'test-folder' };
      hook.handleStore.verifyPermission.mockResolvedValue(true);

      const mockChanges = [
        { id: 'abc-123', path: 'note1.md', version: 1 },
        { id: 'def-456', path: 'note2.md', version: 2 }
      ];
      hook.scanForChanges = vi.fn().mockResolvedValue(mockChanges);

      await hook.scanFiles();

      expect(hook.scanForChanges).toHaveBeenCalled();
      expect(mockPushEvent).toHaveBeenCalledWith('import_files', {
        changes: mockChanges
      });
    });

    it('pushes error event on scan failure', async () => {
      hook.directoryHandle = { name: 'test-folder' };
      hook.handleStore.verifyPermission.mockResolvedValue(true);
      hook.scanForChanges = vi.fn().mockRejectedValue(new Error('Scan failed'));

      await hook.scanFiles();

      expect(mockPushEvent).toHaveBeenCalledWith('import_error', {
        message: 'Scan failed'
      });
    });
  });

  describe('handleImportResult', () => {
    it('updates IndexedDB with new version on success', async () => {
      const noteId = 'abc-123';
      const path = 'projects/work/note';

      await noteMetadataStore.upsert({
        id: noteId,
        version: 1,
        path,
        filename: 'note',
        lastSynced: new Date()
      });

      const payload = {
        results: [
          {
            status: 'success',
            note_id: noteId,
            new_version: 2
          }
        ]
      };

      await hook.handleImportResult(payload);

      const updated = await noteMetadataStore.getByPath(path);
      expect(updated?.version).toBe(2);
    });

    it('handles multiple results with mixed success and errors', async () => {
      const successNoteId = '66666666-6666-6666-6666-666666666666';
      const errorNoteId = '77777777-7777-7777-7777-777777777777';
      const wrongId = '88888888-8888-8888-8888-888888888888';

      await noteMetadataStore.upsert({
        id: successNoteId,
        version: 1,
        path: 'note1',
        filename: 'note1',
        lastSynced: new Date()
      });

      // Setup for auto-fix
      hook.directoryHandle = { name: 'test-folder' };
      hook.getJsonHandle = vi.fn().mockResolvedValue({
        getFile: vi.fn().mockResolvedValue({
          text: vi.fn().mockResolvedValue(JSON.stringify({
            _id: wrongId,
            _schema_version: '1.0',
            name: 'Error Note',
            tags: [],
            data: {}
          }))
        }),
        createWritable: vi.fn().mockResolvedValue({
          write: vi.fn(),
          close: vi.fn()
        })
      });
      hook.readNoteFiles = vi.fn();

      const payload = {
        results: [
          {
            status: 'success',
            note_id: successNoteId,
            new_version: 2
          },
          {
            status: 'error',
            error: {
              type: 'id_not_found',
              provided_id: wrongId,
              suggested_id: errorNoteId,
              path: 'note2.md',
              message: 'Not found'
            }
          }
        ]
      };

      await hook.handleImportResult(payload);
      await new Promise(resolve => setTimeout(resolve, 10));

      const updated = await noteMetadataStore.getByPath('note1');
      expect(updated?.version).toBe(2);
    });

    it('skips version update when note not in IndexedDB', async () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

      const payload = {
        results: [
          {
            status: 'success',
            note_id: 'nonexistent-id',
            new_version: 5
          }
        ]
      };

      await hook.handleImportResult(payload);

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Note not in IndexedDB')
      );

      consoleSpy.mockRestore();
    });

    // Note: id_not_found errors now trigger auto-fix flow instead of just logging
    // See "handleImportResult - auto-fix integration" tests below for auto-fix behavior

    // Note: path_mismatch errors now emit events instead of just logging
    // See "handles path_mismatch errors appropriately" test below for event emission
  });

  describe('loadPersistedHandle', () => {
    it('loads handle and pushes connected event on success', async () => {
      const mockHandle = { name: 'persisted-folder' };
      hook.handleStore.getHandleWithPermission.mockResolvedValue(mockHandle);

      await hook.loadPersistedHandle();

      expect(hook.directoryHandle).toBe(mockHandle);
      expect(mockPushEvent).toHaveBeenCalledWith('directory_connected', {
        name: 'persisted-folder'
      });
    });

    it('does nothing when no persisted handle exists', async () => {
      hook.handleStore.getHandleWithPermission.mockResolvedValue(null);

      await hook.loadPersistedHandle();

      expect(hook.directoryHandle).toBeNull();
      expect(mockPushEvent).not.toHaveBeenCalled();
    });

    it('handles errors gracefully', async () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      hook.handleStore.getHandleWithPermission.mockRejectedValue(
        new Error('Load failed')
      );

      await hook.loadPersistedHandle();

      expect(hook.directoryHandle).toBeNull();
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error loading persisted handle'),
        expect.any(Error)
      );

      consoleSpy.mockRestore();
    });
  });

  describe('scanForChanges', () => {
    it('returns empty array when no directory connected', async () => {
      hook.directoryHandle = null;

      const changes = await hook.scanForChanges();

      expect(changes).toEqual([]);
    });

    it('returns empty array on scan error', async () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
      hook.directoryHandle = { name: 'test-folder' };
      hook.scanDirectory = vi.fn().mockRejectedValue(new Error('Scan error'));

      const changes = await hook.scanForChanges();

      expect(changes).toEqual([]);
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error scanning for changes'),
        expect.any(Error)
      );

      consoleSpy.mockRestore();
    });
  });

  describe('handleImportResult - auto-fix integration', () => {
    beforeEach(async () => {
      await noteMetadataStore.clear();
    });

    it('auto-fixes ID when server and IndexedDB agree (typo case)', async () => {
      // Use valid UUIDs
      const correctId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      const typoId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

      // Setup: IndexedDB has correct ID
      await noteMetadataStore.upsert({
        id: correctId,
        version: 1,
        path: 'projects/work/my-note.md',
        filename: 'my-note',
        lastSynced: new Date()
      });

      // Setup: directory handle
      hook.directoryHandle = { name: 'test-folder' };

      // Mock getJsonHandle to return a writable handle
      const mockJsonContent = {
        _id: typoId,
        _schema_version: '1.0',
        name: 'My Note',
        tags: [],
        data: {}
      };
      let updatedJson = null;

      const mockJsonHandle = {
        getFile: vi.fn().mockResolvedValue({
          text: vi.fn().mockResolvedValue(JSON.stringify(mockJsonContent))
        }),
        createWritable: vi.fn().mockResolvedValue({
          write: vi.fn((content: string) => {
            updatedJson = JSON.parse(content);
          }),
          close: vi.fn()
        })
      };

      hook.getJsonHandle = vi.fn().mockResolvedValue(mockJsonHandle);

      // Mock readNoteFiles for retry
      hook.readNoteFiles = vi.fn().mockResolvedValue({
        markdown: 'Content',
        metadata: {
          name: 'My Note',
          tags: [],
          data: {}
        },
        version: 1
      });

      // Trigger import with error
      await hook.handleImportResult({
        results: [{
          status: 'error',
          error: {
            type: 'id_not_found',
            provided_id: typoId,
            suggested_id: correctId,
            path: 'projects/work/my-note.md',
            message: 'Note not found'
          }
        }]
      });

      // Wait for async operations
      await new Promise(resolve => setTimeout(resolve, 10));

      // Should have called getJsonHandle to fix the file
      expect(hook.getJsonHandle).toHaveBeenCalledWith('projects/work/my-note.md');

      // Should have written corrected JSON
      expect(updatedJson).not.toBeNull();
      expect(updatedJson?._id).toBe(correctId);

      // Should have pushed retry event
      expect(mockPushEvent).toHaveBeenCalledWith('import_files', expect.objectContaining({
        changes: expect.arrayContaining([
          expect.objectContaining({
            id: correctId
          })
        ])
      }));
    });

    it('auto-fixes on new machine when no IndexedDB entry exists', async () => {
      // No IndexedDB entry for this path
      const oldId = '11111111-1111-1111-1111-111111111111';
      const serverId = '22222222-2222-2222-2222-222222222222';

      // Setup: directory handle
      hook.directoryHandle = { name: 'test-folder' };

      const mockJsonContent = {
        _id: oldId,
        _schema_version: '1.0',
        name: 'My Note',
        tags: [],
        data: {}
      };
      let updatedJson = null;

      const mockJsonHandle = {
        getFile: vi.fn().mockResolvedValue({
          text: vi.fn().mockResolvedValue(JSON.stringify(mockJsonContent))
        }),
        createWritable: vi.fn().mockResolvedValue({
          write: vi.fn((content: string) => {
            updatedJson = JSON.parse(content);
          }),
          close: vi.fn()
        })
      };

      hook.getJsonHandle = vi.fn().mockResolvedValue(mockJsonHandle);
      hook.readNoteFiles = vi.fn().mockResolvedValue({
        markdown: 'Content',
        metadata: {
          name: 'My Note',
          tags: [],
          data: {}
        },
        version: undefined
      });

      await hook.handleImportResult({
        results: [{
          status: 'error',
          error: {
            type: 'id_not_found',
            provided_id: oldId,
            suggested_id: serverId,
            path: 'notes/example.md',
            message: 'Note not found'
          }
        }]
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      // Should trust server and auto-fix
      expect(hook.getJsonHandle).toHaveBeenCalledWith('notes/example.md');
      expect(updatedJson?._id).toBe(serverId);
    });

    it('emits conflict event when IDs disagree', async () => {
      // Setup: IndexedDB has different ID than server suggests
      await noteMetadataStore.upsert({
        id: 'local-cached-id',
        version: 1,
        path: 'conflict/note.md',
        filename: 'note',
        lastSynced: new Date()
      });

      await hook.handleImportResult({
        results: [{
          status: 'error',
          error: {
            type: 'id_not_found',
            provided_id: 'json-file-id',
            suggested_id: 'server-says-id',
            path: 'conflict/note.md',
            message: 'Conflicting IDs'
          }
        }]
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      // Should emit conflict event for UI to handle
      expect(mockPushEvent).toHaveBeenCalledWith('id_conflict', {
        path: 'conflict/note.md',
        jsonId: 'json-file-id',
        serverId: 'server-says-id',
        localId: 'local-cached-id',
        reason: expect.stringContaining('Conflicting IDs')
      });
    });

    it('handles successful import by updating IndexedDB version', async () => {
      await noteMetadataStore.upsert({
        id: 'note-123',
        version: 1,
        path: 'success/note.md',
        filename: 'note',
        lastSynced: new Date()
      });

      await hook.handleImportResult({
        results: [{
          status: 'success',
          note_id: 'note-123',
          new_version: 2
        }]
      });

      // Should update IndexedDB with new version
      const metadata = await noteMetadataStore.getById('note-123');
      expect(metadata?.version).toBe(2);
    });

    it('handles path_mismatch errors appropriately', async () => {
      await hook.handleImportResult({
        results: [{
          status: 'error',
          error: {
            type: 'path_mismatch',
            note_id: 'abc-123',
            expected_path: 'old/path.md',
            actual_path: 'new/path.md',
            message: 'Path mismatch'
          }
        }]
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      // Should emit path mismatch event
      expect(mockPushEvent).toHaveBeenCalledWith('path_mismatch', {
        note_id: 'abc-123',
        expected_path: 'old/path.md',
        actual_path: 'new/path.md',
        message: 'Path mismatch'
      });
    });

    it('handles generic errors without crashing', async () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      await hook.handleImportResult({
        results: [{
          status: 'error',
          error: {
            type: 'unknown_error',
            message: 'Something went wrong'
          }
        }]
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      // Should log error
      expect(consoleSpy).toHaveBeenCalled();

      consoleSpy.mockRestore();
    });

    it('processes multiple results with mixed success/error', async () => {
      const note1Id = '33333333-3333-3333-3333-333333333333';
      const wrongId = '44444444-4444-4444-4444-444444444444';
      const correctId = '55555555-5555-5555-5555-555555555555';

      await noteMetadataStore.upsert({
        id: note1Id,
        version: 1,
        path: 'note1.md',
        filename: 'note1',
        lastSynced: new Date()
      });

      // Setup: directory handle for auto-fix
      hook.directoryHandle = { name: 'test-folder' };
      hook.getJsonHandle = vi.fn().mockResolvedValue({
        getFile: vi.fn().mockResolvedValue({
          text: vi.fn().mockResolvedValue(JSON.stringify({
            _id: wrongId,
            _schema_version: '1.0',
            name: 'Note 2',
            tags: [],
            data: {}
          }))
        }),
        createWritable: vi.fn().mockResolvedValue({
          write: vi.fn(),
          close: vi.fn()
        })
      });
      hook.readNoteFiles = vi.fn().mockResolvedValue({
        markdown: 'Content',
        metadata: { name: 'Note 2', tags: [], data: {} },
        version: undefined
      });

      await hook.handleImportResult({
        results: [
          {
            status: 'success',
            note_id: note1Id,
            new_version: 2
          },
          {
            status: 'error',
            error: {
              type: 'id_not_found',
              provided_id: wrongId,
              suggested_id: correctId,
              path: 'note2.md',
              message: 'Not found'
            }
          }
        ]
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      // Should handle both
      const metadata = await noteMetadataStore.getById(note1Id);
      expect(metadata?.version).toBe(2);

      // Should attempt auto-fix for error case
      expect(mockPushEvent).toHaveBeenCalledWith('import_files', expect.objectContaining({
        changes: expect.arrayContaining([
          expect.objectContaining({
            id: correctId
          })
        ])
      }));
    });
  });
});
