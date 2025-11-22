import { describe, it, expect, beforeEach } from 'vitest';
import { JsonFileManager, NoteMetadataJson } from './json_file_manager';

describe('JsonFileManager', () => {
  let manager: JsonFileManager;

  beforeEach(() => {
    manager = new JsonFileManager();
  });

  describe('validate', () => {
    it('validates correct JSON metadata', () => {
      const validData: NoteMetadataJson = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Note',
        tags: ['test', 'example'],
        data: { custom_field: 'value' }
      };

      expect(() => manager.validate(validData)).not.toThrow();
    });

    it('throws on missing _id field', () => {
      const invalidData = {
        _schema_version: '1.0',
        name: 'Test Note',
        tags: [],
        data: {}
      } as any;

      expect(() => manager.validate(invalidData)).toThrow('Missing or invalid _id field');
    });

    it('throws on invalid UUID format', () => {
      const invalidData = {
        _schema_version: '1.0',
        _id: 'not-a-uuid',
        name: 'Test Note',
        tags: [],
        data: {}
      };

      expect(() => manager.validate(invalidData)).toThrow('Invalid UUID format');
    });

    it('throws on missing name field', () => {
      const invalidData = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        tags: [],
        data: {}
      } as any;

      expect(() => manager.validate(invalidData)).toThrow('Missing or invalid name field');
    });

    it('throws on non-array tags', () => {
      const invalidData = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Note',
        tags: 'not-an-array',
        data: {}
      } as any;

      expect(() => manager.validate(invalidData)).toThrow('tags must be an array');
    });

    it('throws on missing data object', () => {
      const invalidData = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Note',
        tags: []
      } as any;

      expect(() => manager.validate(invalidData)).toThrow('data must be an object');
    });

    it('throws on null data field', () => {
      const invalidData = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Note',
        tags: [],
        data: null
      } as any;

      expect(() => manager.validate(invalidData)).toThrow('data must be an object');
    });

    it('accepts UUID in various cases', () => {
      const upperCaseData = {
        _schema_version: '1.0',
        _id: '123E4567-E89B-12D3-A456-426614174000',
        name: 'Test Note',
        tags: [],
        data: {}
      };

      expect(() => manager.validate(upperCaseData)).not.toThrow();
    });
  });

  describe('createDefault', () => {
    it('creates default metadata with required fields', () => {
      const id = '123e4567-e89b-12d3-a456-426614174000';
      const name = 'My New Note';

      const metadata = manager.createDefault(id, name);

      expect(metadata._schema_version).toBe('1.0');
      expect(metadata._id).toBe(id);
      expect(metadata.name).toBe(name);
      expect(metadata.tags).toEqual([]);
      expect(metadata.data).toEqual({});
      expect(metadata._note).toBeDefined();
      expect(metadata._note).toContain('system-generated');
    });
  });

  describe('migrateFromOldFormat', () => {
    it('migrates old format to new format', () => {
      const oldData = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        version: 5,
        note_type_id: 'some-type',
        inserted_at: '2024-01-01',
        updated_at: '2024-01-02',
        name: 'Old Note',
        tags: ['old'],
        data: { field: 'value' }
      };

      const migrated = manager.migrateFromOldFormat(oldData);

      expect(migrated._schema_version).toBe('1.0');
      expect(migrated._id).toBe('123e4567-e89b-12d3-a456-426614174000');
      expect(migrated.name).toBe('Old Note');
      expect(migrated.tags).toEqual(['old']);
      expect(migrated.data).toEqual({ field: 'value' });
      expect(migrated._note).toBeDefined();

      expect('version' in migrated).toBe(false);
      expect('note_type_id' in migrated).toBe(false);
      expect('inserted_at' in migrated).toBe(false);
      expect('updated_at' in migrated).toBe(false);
      expect('id' in migrated).toBe(false);
    });

    it('handles missing optional fields in old format', () => {
      const oldData = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        version: 1
      };

      const migrated = manager.migrateFromOldFormat(oldData);

      expect(migrated._id).toBe('123e4567-e89b-12d3-a456-426614174000');
      expect(migrated.name).toBe('');
      expect(migrated.tags).toEqual([]);
      expect(migrated.data).toEqual({});
    });
  });

  describe('File System Access API integration', () => {
    it('serializes and deserializes JSON correctly', () => {
      const metadata: NoteMetadataJson = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Note',
        tags: ['tag1', 'tag2'],
        data: { custom: 'field', nested: { value: 123 } }
      };

      const json = JSON.stringify(metadata, null, 2);
      const parsed = JSON.parse(json) as NoteMetadataJson;

      expect(() => manager.validate(parsed)).not.toThrow();
      expect(parsed).toEqual(metadata);
    });

    it('preserves field order in createDefault', () => {
      const metadata = manager.createDefault(
        '123e4567-e89b-12d3-a456-426614174000',
        'Test'
      );

      const keys = Object.keys(metadata);
      expect(keys[0]).toBe('_schema_version');
      expect(keys[1]).toBe('_id');
      expect(keys[2]).toBe('_note');
      expect(keys[3]).toBe('name');
      expect(keys[4]).toBe('tags');
      expect(keys[5]).toBe('data');
    });
  });

  describe('edge cases', () => {
    it('validates empty tags array', () => {
      const data: NoteMetadataJson = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test',
        tags: [],
        data: {}
      };

      expect(() => manager.validate(data)).not.toThrow();
    });

    it('validates empty data object', () => {
      const data: NoteMetadataJson = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test',
        tags: [],
        data: {}
      };

      expect(() => manager.validate(data)).not.toThrow();
    });

    it('validates complex nested data', () => {
      const data: NoteMetadataJson = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test',
        tags: [],
        data: {
          nested: {
            deep: {
              value: [1, 2, 3]
            }
          },
          array: ['a', 'b', 'c'],
          number: 42,
          boolean: true
        }
      };

      expect(() => manager.validate(data)).not.toThrow();
    });

    it('accepts _note field if present', () => {
      const data: NoteMetadataJson = {
        _schema_version: '1.0',
        _id: '123e4567-e89b-12d3-a456-426614174000',
        _note: 'Custom note',
        name: 'Test',
        tags: [],
        data: {}
      };

      expect(() => manager.validate(data)).not.toThrow();
    });
  });
});
