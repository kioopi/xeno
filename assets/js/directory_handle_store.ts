/**
 * DirectoryHandleStore
 *
 * Manages persistence of FileSystemDirectoryHandle in IndexedDB.
 * Allows the app to remember the user's selected folder across page reloads.
 *
 * Test Cases (Manual - File System API not available in automated tests):
 * 1. Store a directory handle and verify it's persisted
 * 2. Retrieve a stored handle and check permissions
 * 3. Re-request permissions if expired
 * 4. Clear stored handle on user request
 * 5. Handle IndexedDB errors gracefully
 */

const DB_NAME = 'XenoSyncDB';
const STORE_NAME = 'directoryHandles';
const DB_VERSION = 1;
const HANDLE_KEY = 'syncDirectory';

export class DirectoryHandleStore {
  private db: IDBDatabase | null = null;

  /**
   * Initialize IndexedDB connection
   */
  async init(): Promise<IDBDatabase> {
    if (this.db) {
      return this.db;
    }

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => {
        reject(new Error('Failed to open IndexedDB'));
      };

      request.onsuccess = () => {
        this.db = request.result;
        resolve(this.db);
      };

      request.onupgradeneeded = (event: IDBVersionChangeEvent) => {
        const db = (event.target as IDBOpenDBRequest).result;

        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME);
        }
      };
    });
  }

  /**
   * Store a directory handle in IndexedDB
   */
  async storeHandle(handle: FileSystemDirectoryHandle): Promise<void> {
    await this.init();

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.put(handle, HANDLE_KEY);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(new Error('Failed to store directory handle'));
    });
  }

  /**
   * Retrieve the stored directory handle
   */
  async getHandle(): Promise<FileSystemDirectoryHandle | null> {
    await this.init();

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([STORE_NAME], 'readonly');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.get(HANDLE_KEY);

      request.onsuccess = () => {
        resolve(request.result || null);
      };

      request.onerror = () => {
        reject(new Error('Failed to retrieve directory handle'));
      };
    });
  }

  /**
   * Check if handle has the required permissions
   */
  async verifyPermission(
    handle: FileSystemDirectoryHandle,
    readWrite: boolean = true
  ): Promise<boolean> {
    const options: FileSystemHandlePermissionDescriptor = {};

    if (readWrite) {
      options.mode = 'readwrite';
    }

    const state = await handle.queryPermission(options);

    if (state === 'granted') {
      return true;
    }

    if (state === 'prompt') {
      const newState = await handle.requestPermission(options);
      return newState === 'granted';
    }

    return false;
  }

  /**
   * Clear the stored directory handle
   */
  async clearHandle(): Promise<void> {
    await this.init();

    return new Promise((resolve, reject) => {
      const transaction = this.db!.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.delete(HANDLE_KEY);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(new Error('Failed to clear directory handle'));
    });
  }

  /**
   * Get handle with automatic permission verification
   */
  async getHandleWithPermission(): Promise<FileSystemDirectoryHandle | null> {
    try {
      const handle = await this.getHandle();

      if (!handle) {
        return null;
      }

      const hasPermission = await this.verifyPermission(handle);

      if (!hasPermission) {
        await this.clearHandle();
        return null;
      }

      return handle;
    } catch (error) {
      console.error('Error getting handle with permission:', error);
      return null;
    }
  }
}
