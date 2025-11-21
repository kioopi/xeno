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
  constructor() {
    this.db = null;
  }

  /**
   * Initialize IndexedDB connection
   * @returns {Promise<IDBDatabase>}
   */
  async init() {
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

      request.onupgradeneeded = (event) => {
        const db = event.target.result;

        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME);
        }
      };
    });
  }

  /**
   * Store a directory handle in IndexedDB
   * @param {FileSystemDirectoryHandle} handle - The directory handle to store
   * @returns {Promise<void>}
   */
  async storeHandle(handle) {
    await this.init();

    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.put(handle, HANDLE_KEY);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(new Error('Failed to store directory handle'));
    });
  }

  /**
   * Retrieve the stored directory handle
   * @returns {Promise<FileSystemDirectoryHandle|null>}
   */
  async getHandle() {
    await this.init();

    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readonly');
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
   * @param {FileSystemDirectoryHandle} handle - The handle to check
   * @param {boolean} readWrite - Whether to check for write permission
   * @returns {Promise<boolean>}
   */
  async verifyPermission(handle, readWrite = true) {
    const options = {};

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
   * @returns {Promise<void>}
   */
  async clearHandle() {
    await this.init();

    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([STORE_NAME], 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.delete(HANDLE_KEY);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(new Error('Failed to clear directory handle'));
    });
  }

  /**
   * Get handle with automatic permission verification
   * @returns {Promise<FileSystemDirectoryHandle|null>}
   */
  async getHandleWithPermission() {
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
