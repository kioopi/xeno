/**
 * Manages reading/writing JSON metadata files
 *
 * This module handles the JSON sidecar files (filename.json) that accompany
 * each markdown note. The JSON contains user-editable metadata (name, tags, data)
 * and a system-generated ID (_id).
 */

export interface NoteMetadataJson {
  _schema_version: string;
  _id: string;
  _note?: string;
  name: string;
  tags: string[];
  data: Record<string, any>;
}

export class JsonFileManager {
  private readonly UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  private readonly SCHEMA_VERSION = '1.0';
  private readonly SYSTEM_NOTE = 'Fields prefixed with _ are system-generated. Do not edit unless you know what you\'re doing.';

  /**
   * Read JSON metadata file
   */
  async read(fileHandle: FileSystemFileHandle): Promise<NoteMetadataJson> {
    const file = await fileHandle.getFile();
    const text = await file.text();

    try {
      const data = JSON.parse(text);

      if (data.id && !data._id) {
        console.log(`Migrating ${fileHandle.name} to new format`);
        return this.migrateFromOldFormat(data);
      }

      this.validate(data);
      return data;
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Invalid JSON in ${fileHandle.name}: ${error.message}`);
      }
      throw error;
    }
  }

  /**
   * Write JSON metadata file
   */
  async write(
    fileHandle: FileSystemFileHandle,
    metadata: NoteMetadataJson
  ): Promise<void> {
    this.validate(metadata);

    const writable = await fileHandle.createWritable();
    await writable.write(JSON.stringify(metadata, null, 2));
    await writable.close();
  }

  /**
   * Update only the _id field (for auto-fix)
   */
  async updateId(
    fileHandle: FileSystemFileHandle,
    newId: string
  ): Promise<void> {
    const metadata = await this.read(fileHandle);
    metadata._id = newId;
    await this.write(fileHandle, metadata);
  }

  /**
   * Validate JSON metadata structure
   * Throws an error if validation fails
   */
  validate(data: any): asserts data is NoteMetadataJson {
    if (!data._id || typeof data._id !== 'string') {
      throw new Error('Missing or invalid _id field');
    }

    if (!this.UUID_REGEX.test(data._id)) {
      throw new Error(`Invalid UUID format: ${data._id}`);
    }

    if (typeof data.name !== 'string') {
      throw new Error('Missing or invalid name field');
    }

    if (!Array.isArray(data.tags)) {
      throw new Error('tags must be an array');
    }

    if (typeof data.data !== 'object' || data.data === null) {
      throw new Error('data must be an object');
    }
  }

  /**
   * Create default metadata for new note
   */
  createDefault(id: string, name: string): NoteMetadataJson {
    return {
      _schema_version: this.SCHEMA_VERSION,
      _id: id,
      _note: this.SYSTEM_NOTE,
      name: name,
      tags: [],
      data: {}
    };
  }

  /**
   * Migrate old format to new format
   * Old format: { id, version, note_type_id, inserted_at, updated_at, name, tags, data }
   * New format: { _schema_version, _id, _note, name, tags, data }
   */
  migrateFromOldFormat(oldData: any): NoteMetadataJson {
    return {
      _schema_version: this.SCHEMA_VERSION,
      _id: oldData.id,
      _note: this.SYSTEM_NOTE,
      name: oldData.name || '',
      tags: oldData.tags || [],
      data: oldData.data || {}
    };
  }
}

export const jsonFileManager = new JsonFileManager();
