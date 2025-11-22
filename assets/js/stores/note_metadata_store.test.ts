import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { NoteMetadataStore } from './note_metadata_store';
import type { NoteMetadata } from './note_metadata_store';

describe('NoteMetadataStore', () => {
  let store: NoteMetadataStore;

  beforeEach(() => {
    store = new NoteMetadataStore();
  });

  afterEach(async () => {
    await store.clear();
  });

  describe('upsert and getByPath', () => {
    it('stores and retrieves metadata by path', async () => {
      const metadata: NoteMetadata = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        version: 1,
        path: 'projects/work/meeting-notes',
        filename: 'meeting-notes',
        lastSynced: new Date('2024-01-01T10:00:00Z')
      };

      await store.upsert(metadata);
      const retrieved = await store.getByPath('projects/work/meeting-notes');

      expect(retrieved).toBeDefined();
      expect(retrieved?.id).toBe('550e8400-e29b-41d4-a716-446655440000');
      expect(retrieved?.version).toBe(1);
      expect(retrieved?.path).toBe('projects/work/meeting-notes');
      expect(retrieved?.filename).toBe('meeting-notes');
    });

    it('returns undefined for non-existent path', async () => {
      const result = await store.getByPath('non/existent/path');
      expect(result).toBeUndefined();
    });

    it('updates existing metadata on upsert', async () => {
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'my-note',
        filename: 'my-note',
        lastSynced: new Date()
      };

      await store.upsert(metadata);

      const updated: NoteMetadata = {
        ...metadata,
        version: 2
      };

      await store.upsert(updated);
      const retrieved = await store.getByPath('my-note');

      expect(retrieved?.version).toBe(2);
    });

    it('automatically updates lastSynced on upsert', async () => {
      const oldDate = new Date('2024-01-01T00:00:00Z');
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'my-note',
        filename: 'my-note',
        lastSynced: oldDate
      };

      await store.upsert(metadata);
      const retrieved = await store.getByPath('my-note');

      expect(retrieved?.lastSynced).not.toEqual(oldDate);
      expect(retrieved?.lastSynced.getTime()).toBeGreaterThan(oldDate.getTime());
    });
  });

  describe('getById', () => {
    it('retrieves metadata by note ID', async () => {
      const metadata: NoteMetadata = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        version: 1,
        path: 'projects/work/note',
        filename: 'note',
        lastSynced: new Date()
      };

      await store.upsert(metadata);
      const retrieved = await store.getById('550e8400-e29b-41d4-a716-446655440000');

      expect(retrieved).toBeDefined();
      expect(retrieved?.path).toBe('projects/work/note');
    });

    it('returns undefined for non-existent ID', async () => {
      const result = await store.getById('non-existent-id');
      expect(result).toBeUndefined();
    });
  });

  describe('getByPaths', () => {
    it('retrieves multiple metadata entries by paths', async () => {
      const metadata1: NoteMetadata = {
        id: 'id-1',
        version: 1,
        path: 'path-1',
        filename: 'note-1',
        lastSynced: new Date()
      };

      const metadata2: NoteMetadata = {
        id: 'id-2',
        version: 2,
        path: 'path-2',
        filename: 'note-2',
        lastSynced: new Date()
      };

      await store.upsert(metadata1);
      await store.upsert(metadata2);

      const results = await store.getByPaths(['path-1', 'path-2', 'non-existent']);

      expect(results.size).toBe(2);
      expect(results.get('path-1')?.id).toBe('id-1');
      expect(results.get('path-2')?.id).toBe('id-2');
      expect(results.get('non-existent')).toBeUndefined();
    });

    it('returns empty map for non-existent paths', async () => {
      const results = await store.getByPaths(['non-existent-1', 'non-existent-2']);
      expect(results.size).toBe(0);
    });
  });

  describe('upsertBatch', () => {
    it('stores multiple metadata entries efficiently', async () => {
      const metadataList: NoteMetadata[] = [
        {
          id: 'id-1',
          version: 1,
          path: 'path-1',
          filename: 'note-1',
          lastSynced: new Date()
        },
        {
          id: 'id-2',
          version: 2,
          path: 'path-2',
          filename: 'note-2',
          lastSynced: new Date()
        },
        {
          id: 'id-3',
          version: 3,
          path: 'path-3',
          filename: 'note-3',
          lastSynced: new Date()
        }
      ];

      await store.upsertBatch(metadataList);

      const retrieved1 = await store.getByPath('path-1');
      const retrieved2 = await store.getByPath('path-2');
      const retrieved3 = await store.getByPath('path-3');

      expect(retrieved1?.id).toBe('id-1');
      expect(retrieved2?.id).toBe('id-2');
      expect(retrieved3?.id).toBe('id-3');
    });
  });

  describe('updateVersion', () => {
    it('updates version for existing metadata', async () => {
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'my-note',
        filename: 'my-note',
        lastSynced: new Date()
      };

      await store.upsert(metadata);
      await store.updateVersion('my-note', 5);

      const retrieved = await store.getByPath('my-note');
      expect(retrieved?.version).toBe(5);
    });

    it('updates lastSynced when updating version', async () => {
      const oldDate = new Date('2024-01-01T00:00:00Z');
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'my-note',
        filename: 'my-note',
        lastSynced: oldDate
      };

      await store.upsert(metadata);
      await store.updateVersion('my-note', 2);

      const retrieved = await store.getByPath('my-note');
      expect(retrieved?.lastSynced.getTime()).toBeGreaterThan(oldDate.getTime());
    });

    it('handles updateVersion for non-existent path gracefully', async () => {
      await expect(store.updateVersion('non-existent', 5)).resolves.not.toThrow();
    });
  });

  describe('updatePath', () => {
    it('updates path for existing metadata (rename)', async () => {
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'old-path',
        filename: 'old-note',
        lastSynced: new Date()
      };

      await store.upsert(metadata);
      await store.updatePath('old-path', 'new-path/renamed-note');

      const oldExists = await store.getByPath('old-path');
      const newExists = await store.getByPath('new-path/renamed-note');

      expect(oldExists).toBeUndefined();
      expect(newExists).toBeDefined();
      expect(newExists?.id).toBe('abc-123');
      expect(newExists?.path).toBe('new-path/renamed-note');
      expect(newExists?.filename).toBe('renamed-note');
    });

    it('extracts filename correctly from new path', async () => {
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'old',
        filename: 'old',
        lastSynced: new Date()
      };

      await store.upsert(metadata);
      await store.updatePath('old', 'dir1/dir2/dir3/new-filename');

      const retrieved = await store.getByPath('dir1/dir2/dir3/new-filename');
      expect(retrieved?.filename).toBe('new-filename');
    });
  });

  describe('delete', () => {
    it('deletes metadata by path', async () => {
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'to-delete',
        filename: 'to-delete',
        lastSynced: new Date()
      };

      await store.upsert(metadata);

      let retrieved = await store.getByPath('to-delete');
      expect(retrieved).toBeDefined();

      await store.delete('to-delete');

      retrieved = await store.getByPath('to-delete');
      expect(retrieved).toBeUndefined();
    });

    it('handles delete for non-existent path gracefully', async () => {
      await expect(store.delete('non-existent')).resolves.not.toThrow();
    });
  });

  describe('getAll', () => {
    it('retrieves all metadata entries', async () => {
      const metadataList: NoteMetadata[] = [
        {
          id: 'id-1',
          version: 1,
          path: 'path-1',
          filename: 'note-1',
          lastSynced: new Date()
        },
        {
          id: 'id-2',
          version: 2,
          path: 'path-2',
          filename: 'note-2',
          lastSynced: new Date()
        }
      ];

      await store.upsertBatch(metadataList);
      const all = await store.getAll();

      expect(all.length).toBe(2);
      expect(all.find(m => m.id === 'id-1')).toBeDefined();
      expect(all.find(m => m.id === 'id-2')).toBeDefined();
    });

    it('returns empty array when no metadata exists', async () => {
      const all = await store.getAll();
      expect(all).toEqual([]);
    });
  });

  describe('clear', () => {
    it('clears all metadata', async () => {
      const metadata: NoteMetadata = {
        id: 'abc-123',
        version: 1,
        path: 'my-note',
        filename: 'my-note',
        lastSynced: new Date()
      };

      await store.upsert(metadata);

      let all = await store.getAll();
      expect(all.length).toBe(1);

      await store.clear();

      all = await store.getAll();
      expect(all.length).toBe(0);
    });
  });
});
