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
      const successNoteId = 'abc-123';
      const errorNoteId = 'def-456';

      await noteMetadataStore.upsert({
        id: successNoteId,
        version: 1,
        path: 'note1',
        filename: 'note1',
        lastSynced: new Date()
      });

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
              provided_id: 'wrong-id',
              suggested_id: errorNoteId,
              message: 'Not found'
            }
          }
        ]
      };

      await hook.handleImportResult(payload);

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

    it('logs id_not_found errors with suggestion context', async () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

      const payload = {
        results: [
          {
            status: 'error',
            error: {
              type: 'id_not_found',
              provided_id: 'wrong-id',
              suggested_id: 'correct-id',
              path: 'my-note',
              message: 'Note not found'
            }
          }
        ]
      };

      await hook.handleImportResult(payload);

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('ID Not Found'),
        expect.objectContaining({
          provided_id: 'wrong-id',
          suggested_id: 'correct-id',
          path: 'my-note'
        })
      );

      consoleSpy.mockRestore();
    });

    it('logs path_mismatch errors with location details', async () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

      const payload = {
        results: [
          {
            status: 'error',
            error: {
              type: 'path_mismatch',
              note_id: 'abc-123',
              expected_path: 'old/path',
              actual_path: 'new/path',
              message: 'Path mismatch'
            }
          }
        ]
      };

      await hook.handleImportResult(payload);

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Path Mismatch'),
        expect.objectContaining({
          note_id: 'abc-123',
          expected: 'old/path',
          actual: 'new/path'
        })
      );

      consoleSpy.mockRestore();
    });
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
});
