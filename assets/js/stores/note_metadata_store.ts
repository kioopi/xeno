/**
 * IndexedDB store for note metadata (version tracking)
 *
 * This store maintains the mapping between file paths and note IDs/versions.
 * It acts as a local cache to avoid querying the server for version info
 * on every import.
 *
 * Primary key: path (file path like "projects/work/my-note")
 * Secondary index: id (note UUID for reverse lookup)
 */

import { openDB, type IDBPDatabase, type DBSchema } from 'idb';

export interface NoteMetadata {
  id: string;           // UUID (matches _id in JSON file)
  version: number;      // Current version for optimistic locking
  path: string;         // Relative path: "projects/work/my-note" (PRIMARY KEY)
  filename: string;     // Just the basename: "my-note"
  lastSynced: Date;     // When last successfully imported/exported
}

interface NoteMetadataDB extends DBSchema {
  metadata: {
    key: string;        // path
    value: NoteMetadata;
    indexes: {
      'by-id': string;  // Secondary index for reverse lookup
    };
  };
}

export class NoteMetadataStore {
  private dbPromise: Promise<IDBPDatabase<NoteMetadataDB>>;
  private static readonly DB_NAME = 'xeno-note-metadata';
  private static readonly DB_VERSION = 1;
  private static readonly STORE_NAME = 'metadata';

  constructor() {
    this.dbPromise = this.initDB();
  }

  private async initDB(): Promise<IDBPDatabase<NoteMetadataDB>> {
    return openDB<NoteMetadataDB>(
      NoteMetadataStore.DB_NAME,
      NoteMetadataStore.DB_VERSION,
      {
        upgrade(db) {
          const store = db.createObjectStore(NoteMetadataStore.STORE_NAME, {
            keyPath: 'path'
          });
          store.createIndex('by-id', 'id', { unique: false });
        },
      }
    );
  }

  /**
   * Get metadata by file path (primary lookup)
   */
  async getByPath(path: string): Promise<NoteMetadata | undefined> {
    const db = await this.dbPromise;
    return db.get(NoteMetadataStore.STORE_NAME, path);
  }

  /**
   * Get metadata by note ID (reverse lookup)
   * Note: Returns first match if multiple paths have same ID (shouldn't happen)
   */
  async getById(id: string): Promise<NoteMetadata | undefined> {
    const db = await this.dbPromise;
    return db.getFromIndex(NoteMetadataStore.STORE_NAME, 'by-id', id);
  }

  /**
   * Get all metadata entries for multiple paths (batch operation)
   */
  async getByPaths(paths: string[]): Promise<Map<string, NoteMetadata>> {
    const db = await this.dbPromise;
    const results = new Map<string, NoteMetadata>();

    for (const path of paths) {
      const metadata = await db.get(NoteMetadataStore.STORE_NAME, path);
      if (metadata) {
        results.set(path, metadata);
      }
    }

    return results;
  }

  /**
   * Store or update metadata
   */
  async upsert(metadata: NoteMetadata): Promise<void> {
    const db = await this.dbPromise;
    await db.put(NoteMetadataStore.STORE_NAME, {
      ...metadata,
      lastSynced: new Date(),
    });
  }

  /**
   * Batch upsert (more efficient for multiple notes)
   */
  async upsertBatch(metadataList: NoteMetadata[]): Promise<void> {
    const db = await this.dbPromise;
    const tx = db.transaction(NoteMetadataStore.STORE_NAME, 'readwrite');

    await Promise.all([
      ...metadataList.map(meta =>
        tx.store.put({
          ...meta,
          lastSynced: new Date(),
        })
      ),
      tx.done,
    ]);
  }

  /**
   * Update version after successful import
   */
  async updateVersion(path: string, newVersion: number): Promise<void> {
    const db = await this.dbPromise;
    const existing = await db.get(NoteMetadataStore.STORE_NAME, path);

    if (existing) {
      await db.put(NoteMetadataStore.STORE_NAME, {
        ...existing,
        version: newVersion,
        lastSynced: new Date(),
      });
    } else {
      console.warn(`Cannot update version: no metadata found for path ${path}`);
    }
  }

  /**
   * Update path (for handling renames)
   */
  async updatePath(oldPath: string, newPath: string): Promise<void> {
    const db = await this.dbPromise;
    const existing = await db.get(NoteMetadataStore.STORE_NAME, oldPath);

    if (existing) {
      const tx = db.transaction(NoteMetadataStore.STORE_NAME, 'readwrite');
      await tx.store.delete(oldPath);
      await tx.store.put({
        ...existing,
        path: newPath,
        filename: this.extractFilename(newPath),
      });
      await tx.done;
    }
  }

  /**
   * Delete metadata (when note is deleted)
   */
  async delete(path: string): Promise<void> {
    const db = await this.dbPromise;
    await db.delete(NoteMetadataStore.STORE_NAME, path);
  }

  /**
   * Get all metadata (for debugging/admin)
   */
  async getAll(): Promise<NoteMetadata[]> {
    const db = await this.dbPromise;
    return db.getAll(NoteMetadataStore.STORE_NAME);
  }

  /**
   * Clear all metadata (for testing/reset)
   */
  async clear(): Promise<void> {
    const db = await this.dbPromise;
    await db.clear(NoteMetadataStore.STORE_NAME);
  }

  /**
   * Extract filename from path
   * @private
   */
  private extractFilename(path: string): string {
    const parts = path.split('/');
    return parts[parts.length - 1];
  }
}

// Singleton instance
export const noteMetadataStore = new NoteMetadataStore();
