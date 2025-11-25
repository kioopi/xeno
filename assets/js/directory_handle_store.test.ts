import { describe, it, expect, vi, beforeEach } from 'vitest';
import { DirectoryHandleStore } from './directory_handle_store';
import 'fake-indexeddb/auto';

describe('DirectoryHandleStore', () => {
  let store: DirectoryHandleStore;

  beforeEach(async () => {
    // Close any existing database connection
    if (store && (store as any).db) {
      try {
        (store as any).db.close();
      } catch (error) {
        // Ignore errors
      }
    }

    store = new DirectoryHandleStore();

    try {
      const deleteRequest = indexedDB.deleteDatabase('XenoSyncDB');
      await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => resolve(undefined), 100);
        deleteRequest.onsuccess = () => {
          clearTimeout(timeout);
          resolve(undefined);
        };
        deleteRequest.onerror = () => {
          clearTimeout(timeout);
          resolve(undefined);
        };
        deleteRequest.onblocked = () => {
          clearTimeout(timeout);
          resolve(undefined);
        };
      });
    } catch (error) {
      // Ignore errors during cleanup
    }
  });

  describe('init', () => {
    it('initializes IndexedDB connection', async () => {
      const db = await store.init();

      expect(db).toBeDefined();
      expect(db.name).toBe('XenoSyncDB');
      expect(db.objectStoreNames.contains('directoryHandles')).toBe(true);
    });

    it('returns existing connection on subsequent calls', async () => {
      const db1 = await store.init();
      const db2 = await store.init();

      expect(db1).toBe(db2);
    });

    it('creates object store on first initialization', async () => {
      const db = await store.init();

      expect(db.objectStoreNames.contains('directoryHandles')).toBe(true);
    });
  });

  describe('storeHandle and getHandle', () => {
    it('stores and retrieves a directory handle', async () => {
      const mockHandle = {
        name: 'test-folder',
        kind: 'directory'
      } as FileSystemDirectoryHandle;

      await store.storeHandle(mockHandle);
      const retrieved = await store.getHandle();

      expect(retrieved).toEqual(mockHandle);
    });

    it('returns null when no handle is stored', async () => {
      const retrieved = await store.getHandle();

      expect(retrieved).toBeNull();
    });

    it('overwrites existing handle when storing new one', async () => {
      const handle1 = {
        name: 'folder-1',
        kind: 'directory'
      } as FileSystemDirectoryHandle;

      const handle2 = {
        name: 'folder-2',
        kind: 'directory'
      } as FileSystemDirectoryHandle;

      await store.storeHandle(handle1);
      await store.storeHandle(handle2);

      const retrieved = await store.getHandle();
      expect(retrieved).toEqual(handle2);
    });
  });

  describe('clearHandle', () => {
    it('removes stored handle from IndexedDB', async () => {
      const mockHandle = {
        name: 'test-folder',
        kind: 'directory'
      } as FileSystemDirectoryHandle;

      await store.storeHandle(mockHandle);
      await store.clearHandle();

      const retrieved = await store.getHandle();
      expect(retrieved).toBeNull();
    });

    it('succeeds even when no handle is stored', async () => {
      await expect(store.clearHandle()).resolves.not.toThrow();
    });
  });

  describe('verifyPermission', () => {
    it('returns true when permission is granted', async () => {
      const mockHandle = {
        queryPermission: vi.fn().mockResolvedValue('granted'),
        requestPermission: vi.fn()
      } as unknown as FileSystemDirectoryHandle;

      const result = await store.verifyPermission(mockHandle);

      expect(result).toBe(true);
      expect(mockHandle.queryPermission).toHaveBeenCalled();
      expect(mockHandle.requestPermission).not.toHaveBeenCalled();
    });

    it('requests permission when state is prompt and returns true if granted', async () => {
      const mockHandle = {
        queryPermission: vi.fn().mockResolvedValue('prompt'),
        requestPermission: vi.fn().mockResolvedValue('granted')
      } as unknown as FileSystemDirectoryHandle;

      const result = await store.verifyPermission(mockHandle);

      expect(result).toBe(true);
      expect(mockHandle.queryPermission).toHaveBeenCalled();
      expect(mockHandle.requestPermission).toHaveBeenCalled();
    });

    it('returns false when permission is denied', async () => {
      const mockHandle = {
        queryPermission: vi.fn().mockResolvedValue('denied'),
        requestPermission: vi.fn()
      } as unknown as FileSystemDirectoryHandle;

      const result = await store.verifyPermission(mockHandle);

      expect(result).toBe(false);
      expect(mockHandle.requestPermission).not.toHaveBeenCalled();
    });

    it('returns false when permission request is denied', async () => {
      const mockHandle = {
        queryPermission: vi.fn().mockResolvedValue('prompt'),
        requestPermission: vi.fn().mockResolvedValue('denied')
      } as unknown as FileSystemDirectoryHandle;

      const result = await store.verifyPermission(mockHandle);

      expect(result).toBe(false);
    });

    it('uses readwrite mode by default', async () => {
      const mockHandle = {
        queryPermission: vi.fn().mockResolvedValue('granted'),
        requestPermission: vi.fn()
      } as unknown as FileSystemDirectoryHandle;

      await store.verifyPermission(mockHandle);

      expect(mockHandle.queryPermission).toHaveBeenCalledWith({ mode: 'readwrite' });
    });

    it('can verify read-only permission', async () => {
      const mockHandle = {
        queryPermission: vi.fn().mockResolvedValue('granted'),
        requestPermission: vi.fn()
      } as unknown as FileSystemDirectoryHandle;

      await store.verifyPermission(mockHandle, false);

      expect(mockHandle.queryPermission).toHaveBeenCalledWith({});
    });
  });

  describe('getHandleWithPermission', () => {
    it('returns handle when permission is granted', async () => {
      const mockHandle = {
        name: 'test-folder',
        kind: 'directory',
        queryPermission: vi.fn().mockResolvedValue('granted'),
        requestPermission: vi.fn()
      } as unknown as FileSystemDirectoryHandle;

      vi.spyOn(store, 'getHandle').mockResolvedValue(mockHandle);
      vi.spyOn(store, 'verifyPermission').mockResolvedValue(true);

      const result = await store.getHandleWithPermission();

      expect(result).toEqual(mockHandle);
    });

    it('returns null when no handle is stored', async () => {
      const result = await store.getHandleWithPermission();

      expect(result).toBeNull();
    });

    it('clears handle and returns null when permission is denied', async () => {
      const mockHandle = {
        name: 'test-folder',
        kind: 'directory',
        queryPermission: vi.fn().mockResolvedValue('denied'),
        requestPermission: vi.fn()
      } as unknown as FileSystemDirectoryHandle;

      vi.spyOn(store, 'getHandle').mockResolvedValue(mockHandle);
      vi.spyOn(store, 'verifyPermission').mockResolvedValue(false);
      const clearSpy = vi.spyOn(store, 'clearHandle').mockResolvedValue();

      const result = await store.getHandleWithPermission();

      expect(result).toBeNull();
      expect(clearSpy).toHaveBeenCalled();
    });

    it('handles errors gracefully and returns null', async () => {
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      vi.spyOn(store, 'getHandle').mockRejectedValue(new Error('Permission check failed'));

      const result = await store.getHandleWithPermission();

      expect(result).toBeNull();
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Error getting handle with permission'),
        expect.any(Error)
      );

      consoleSpy.mockRestore();
    });

    it('requests permission when state is prompt', async () => {
      const mockHandle = {
        name: 'test-folder',
        kind: 'directory',
        queryPermission: vi.fn().mockResolvedValue('prompt'),
        requestPermission: vi.fn().mockResolvedValue('granted')
      } as unknown as FileSystemDirectoryHandle;

      vi.spyOn(store, 'getHandle').mockResolvedValue(mockHandle);
      const verifySpy = vi.spyOn(store, 'verifyPermission').mockResolvedValue(true);

      const result = await store.getHandleWithPermission();

      expect(result).toEqual(mockHandle);
      expect(verifySpy).toHaveBeenCalledWith(mockHandle);
    });
  });
});
