/**
 * FileSystemHook
 *
 * Phoenix LiveView hook for File System Access API integration.
 *
 * Responsibilities:
 * - Request directory access from user via showDirectoryPicker()
 * - Persist directory handles using IndexedDB
 * - Write markdown and JSON files to local file system
 * - Manage file system permissions
 *
 * Manual Test Cases:
 * 1. Click "Choose Folder" → Browser picker appears → Folder selected
 * 2. Export notes → Files created in selected folder with correct structure
 * 3. Refresh page → Folder remains connected (loaded from IndexedDB)
 * 4. Revoke permissions → Re-prompt on next export attempt
 * 5. Handle errors gracefully with user feedback
 */

import { DirectoryHandleStore } from '../directory_handle_store';
import { noteMetadataStore } from '../stores/note_metadata_store';
import { jsonFileManager } from '../sync/json_file_manager';
import { importErrorHandler } from '../sync/import_error_handler';

interface FileToWrite {
  path: string;
  markdown: string;
  json: string;
  metadata?: {
    note_id: string;
    name: string;
    version?: number;
  };
}

interface WriteFilesPayload {
  files: FileToWrite[];
}

interface LiveViewHook {
  pushEvent(event: string, payload: Record<string, any>): void;
  handleEvent(event: string, callback: (payload: any) => void): void;
}

// TODO TFileSystemHook should inherit from LiveViewHook

interface TFileSystemHook {
  pushEvent(event: string, payload: Record<string, any>): void;
  handleEvent(event: string, callback: (payload: any) => void): void;

  mounted(): void;
  destroyed(): void;
  directoryHandle: FileSystemDirectoryHandle | null;
  handleStore: DirectoryHandleStore;
  loadPersistedHandle(): Promise<void>;
  requestDirectory(): Promise<void>;
  writeFiles(payload: WriteFilesPayload): Promise<void>;
  disconnectDirectory(): Promise<void>;
  scanFiles(): Promise<void>;
  scanForChanges(): Promise<any[]>;
  writeNoteFiles(file: FileToWrite): Promise<void>;
  scanDirectory(dirHandle: FileSystemDirectoryHandle, currentPath: string, changes: any[]): Promise<void>;
  readNoteFiles(path: string): Promise<{ markdown: string, metadata: any, version?: number } | null>;
  handleImportResult(payload: { results: any[] }): Promise<void>;
  getJsonHandle(path: string): Promise<FileSystemFileHandle>;
  retryImportWithCorrectedId(path: string, correctedId: string, originalChange: any): Promise<void>;
}

export const FileSystemHook: TFileSystemHook = {
  directoryHandle: null,
  handleStore: null as any,

  mounted() {
    this.directoryHandle = null;
    this.handleStore = new DirectoryHandleStore();

    this.handleEvent('request_directory', this.requestDirectory.bind(this));
    this.handleEvent('write_files', this.writeFiles.bind(this));
    this.handleEvent('disconnect_directory', this.disconnectDirectory.bind(this));
    this.handleEvent('scan_files', this.scanFiles.bind(this));
    this.handleEvent('import_result', this.handleImportResult.bind(this));

    this.loadPersistedHandle();
  },

  /**
   * Handle import results from the server
   * Updates IndexedDB with new versions and implements auto-fix for ID errors
   */
  async handleImportResult(payload: { results: any[] }) {
    console.group('📥 Import Results');
    console.log('Total results:', payload.results.length);

    for (const result of payload.results) {
      if (result.status === 'success') {
        console.log('✅ Success:', {
          note_id: result.note_id,
          new_version: result.new_version
        });

        // Update IndexedDB with new version
        const metadata = await noteMetadataStore.getById(result.note_id);
        if (metadata) {
          await noteMetadataStore.upsert({
            ...metadata,
            version: result.new_version
          });
          console.log('  💾 Updated IndexedDB version:', result.new_version);
        } else {
          console.warn('  ⚠️ Note not in IndexedDB, skipping version update');
        }
      } else if (result.status === 'error') {
        console.error('❌ Error:', {
          type: result.error.type,
          message: result.error.message,
          details: result.error
        });

        // Handle different error types
        if (result.error.type === 'id_not_found' && result.error.suggested_id) {
          // Auto-fix flow using ImportErrorHandler
          const autoFixResult = await importErrorHandler.handleError(
            result.error,
            result.error.path,
            // Auto-fix callback: update JSON and retry import
            async (correctedId: string) => {
              console.log(`🔧 Auto-fixing ID in ${result.error.path}: ${result.error.provided_id} → ${correctedId}`);

              try {
                // Get JSON file handle and update ID
                const jsonHandle = await this.getJsonHandle(result.error.path);
                await jsonFileManager.updateId(jsonHandle, correctedId);

                // Update IndexedDB with corrected ID
                const localMeta = await noteMetadataStore.getByPath(result.error.path);
                if (localMeta) {
                  await noteMetadataStore.upsert({
                    ...localMeta,
                    id: correctedId
                  });
                }

                // Retry import with corrected ID
                await this.retryImportWithCorrectedId(result.error.path, correctedId, result.originalChange);
              } catch (error) {
                console.error('Failed to auto-fix:', error);
                throw error;
              }
            },
            // Conflict callback: emit event for UI to handle
            async (options) => {
              console.warn('⚠️ ID Conflict - user intervention needed:', options);
              this.pushEvent('id_conflict', {
                path: options.filePath,
                jsonId: options.jsonId,
                serverId: options.serverId,
                localId: options.localId,
                reason: options.reason
              });
              return null; // User will resolve via UI
            }
          );

          if (autoFixResult.action === 'auto_fixed') {
            console.log(`✅ Auto-fix succeeded for ${result.error.path}`);
          }
        } else if (result.error.type === 'path_mismatch') {
          // Emit path mismatch event for UI to handle
          this.pushEvent('path_mismatch', {
            note_id: result.error.note_id,
            expected_path: result.error.expected_path,
            actual_path: result.error.actual_path,
            message: result.error.message
          });
        }
      }
    }

    console.groupEnd();
  },

  /**
   * Request directory access from user
   */
  async requestDirectory() {
    try {
      if (!('showDirectoryPicker' in window)) {
        this.pushEvent('directory_error', {
          message: 'File System Access API not supported in this browser. Please use Chrome or Edge.'
        });
        return;
      }

      const handle = await window.showDirectoryPicker({
        mode: 'readwrite',
        startIn: 'documents'
      });

      this.directoryHandle = handle;

      await this.handleStore.storeHandle(handle);

      this.pushEvent('directory_connected', {
        name: handle.name
      });
    } catch (error: any) {
      if (error.name === 'AbortError') {
        return;
      }

      console.error('Error requesting directory:', error);
      this.pushEvent('directory_error', {
        message: error.message || 'Failed to select directory'
      });
    }
  },

  /**
   * Load persisted directory handle from IndexedDB
   */
  async loadPersistedHandle() {
    try {
      const handle = await this.handleStore.getHandleWithPermission();

      if (handle) {
        this.directoryHandle = handle;
        this.pushEvent('directory_connected', {
          name: handle.name
        });
      }
    } catch (error) {
      console.error('Error loading persisted handle:', error);
    }
  },

  /**
   * Disconnect and clear the directory handle
   */
  async disconnectDirectory() {
    try {
      await this.handleStore.clearHandle();
      this.directoryHandle = null;

      this.pushEvent('directory_disconnected', {});
    } catch (error) {
      console.error('Error disconnecting directory:', error);
      this.pushEvent('directory_error', {
        message: 'Failed to disconnect directory'
      });
    }
  },

  /**
   * Write files to the local file system
   */
  async writeFiles(payload: WriteFilesPayload) {
    try {
      if (!this.directoryHandle) {
        this.pushEvent('export_error', {
          message: 'No directory connected'
        });
        return;
      }

      const hasPermission = await this.handleStore.verifyPermission(this.directoryHandle);

      if (!hasPermission) {
        this.pushEvent('export_error', {
          message: 'Permission denied. Please reconnect the folder.'
        });
        await this.handleStore.clearHandle();
        this.directoryHandle = null;
        return;
      }

      const files = payload.files || [];
      let written = 0;

      for (const file of files) {
        await this.writeNoteFiles(file);
        written++;

        this.pushEvent('export_progress', {
          current: written,
          total: files.length
        });
      }

      this.pushEvent('export_complete', {
        count: written
      });
    } catch (error: any) {
      console.error('Error writing files:', error);
      this.pushEvent('export_error', {
        message: error.message || 'Failed to write files'
      });
    }
  },

  /**
   * Write markdown and JSON files for a single note
   * Uses JsonFileManager for JSON writing and stores metadata in IndexedDB
   */
  async writeNoteFiles(file: FileToWrite) {
    const pathParts = file.path.split('/');
    const filename = pathParts.pop()!;

    let currentDir = this.directoryHandle!;

    for (const dirName of pathParts) {
      if (dirName) {
        currentDir = await currentDir.getDirectoryHandle(dirName, { create: true });
      }
    }

    const baseFilename = filename.replace(/\.[^/.]+$/, '');

    // Write markdown file
    const mdHandle = await currentDir.getFileHandle(`${baseFilename}.md`, { create: true });
    const mdWritable = await mdHandle.createWritable();
    await mdWritable.write(file.markdown);
    await mdWritable.close();

    // Write JSON file using JsonFileManager
    const jsonHandle = await currentDir.getFileHandle(`${baseFilename}.json`, { create: true });
    const jsonMetadata = JSON.parse(file.json);
    await jsonFileManager.write(jsonHandle, jsonMetadata);

    // Store metadata in IndexedDB (if version and ID are available)
    if (file.metadata && file.metadata.note_id && file.metadata.version !== undefined) {
      await noteMetadataStore.upsert({
        id: file.metadata.note_id,
        version: file.metadata.version,
        path: file.path,
        filename: baseFilename,
        lastSynced: new Date()
      });
    }
  },

  async scanFiles() {
    try {
      if (!this.directoryHandle) {
        this.pushEvent('import_error', {
          message: 'No directory connected'
        });
        return;
      }

      const hasPermission = await this.handleStore.verifyPermission(this.directoryHandle);

      if (!hasPermission) {
        console.error('No permission for', this.directoryHandle);
        this.pushEvent('import_error', {
          message: 'Permission denied. Please reconnect the folder.'
        });
        return;
      }

      console.log('🔍 Scanning files for changes...');
      const changes = await this.scanForChanges();

      console.group('📤 Sending changes to server');
      console.log('Total changes:', changes.length);
      changes.forEach((change, idx) => {
        console.log(`Change ${idx + 1}:`, {
          id: change.id,
          path: change.path,
          version: change.version,
          hasVersion: change.version !== undefined,
          name: change.name
        });
      });
      console.groupEnd();

      this.pushEvent('import_files', {
        changes: changes
      });
    } catch (error: any) {
      console.error('Error scanning files:', error);
      this.pushEvent('import_error', {
        message: error.message || 'Failed to scan files'
      });
    }
  },

  /**
   * Read note files (markdown + JSON metadata)
   * Uses JsonFileManager for JSON reading and NoteMetadataStore for version lookup
   */
  async readNoteFiles(path: string): Promise<{ markdown: string, metadata: any, version?: number } | null> {
    try {
      const pathParts = path.split('/').filter(p => p);
      const filename = pathParts.pop()!;

      let currentDir = this.directoryHandle!;

      for (const dirName of pathParts) {
        currentDir = await currentDir.getDirectoryHandle(dirName);
      }

      const baseFilename = filename.replace(/\.[^/.]+$/, '');

      // Read markdown file
      const mdHandle = await currentDir.getFileHandle(`${baseFilename}.md`);
      const mdFile = await mdHandle.getFile();
      const markdown = await mdFile.text();

      // Read JSON file using JsonFileManager
      const jsonHandle = await currentDir.getFileHandle(`${baseFilename}.json`);
      const jsonMetadata = await jsonFileManager.read(jsonHandle);

      // Try to get version from IndexedDB
      const localMeta = await noteMetadataStore.getByPath(path);
      const version = localMeta?.version;

      return {
        markdown,
        metadata: {
          id: jsonMetadata._id,  // Use _id from new format
          name: jsonMetadata.name,
          tags: jsonMetadata.tags,
          data: jsonMetadata.data
        },
        version  // May be undefined if not in IndexedDB
      };
    } catch (error) {
      console.error(`Error reading note files at ${path}:`, error);
      return null;
    }
  },

  // TODO: scanDirectory should return a promise with the changes
  // not alter the changes array it got as an argument
  // TODO: Add a TypeSctipt interface Change.
  async scanForChanges(): Promise<any[]> {
    if (!this.directoryHandle) {
      return [];
    }

    const changes: any[] = [];

    try {
      await this.scanDirectory(this.directoryHandle, '', changes);
      return changes;
    } catch (error) {
      console.error('Error scanning for changes:', error);
      return [];
    }
  },

  /**
   * Scan directory recursively for note files
   * Builds changes array with note data and version from IndexedDB
   */
  async scanDirectory(dirHandle: FileSystemDirectoryHandle, currentPath: string, changes: any[]): Promise<void> {
    for await (const entry of dirHandle.values()) {
      const entryPath = currentPath ? `${currentPath}/${entry.name}` : entry.name;

      if (entry.kind === 'directory') {
        await this.scanDirectory(entry as FileSystemDirectoryHandle, entryPath, changes);
      } else if (entry.kind === 'file' && entry.name.endsWith('.md')) {
        const baseName = entry.name.replace(/\.md$/, '');
        const baseFilePath = currentPath ? `${currentPath}/${baseName}` : baseName;

        // For readNoteFiles, use path without .md extension
        const noteFiles = await this.readNoteFiles(baseFilePath);

        if (noteFiles && noteFiles.metadata && noteFiles.metadata.id) {
          // For the server, send path WITH .md extension to match database
          const serverPath = `${baseFilePath}.md`;

          changes.push({
            id: noteFiles.metadata.id,
            version: noteFiles.version,  // From IndexedDB (may be undefined)
            name: noteFiles.metadata.name,
            tags: noteFiles.metadata.tags,
            data: noteFiles.metadata.data,
            markdown_content: noteFiles.markdown,
            path: serverPath  // Include .md extension to match database
          });
        }
      }
    }
  },

  /**
   * Get JSON file handle for a given path
   * Helper method for auto-fix functionality
   */
  async getJsonHandle(path: string): Promise<FileSystemFileHandle> {
    if (!this.directoryHandle) {
      throw new Error('No directory connected');
    }

    const pathParts = path.replace(/\.md$/, '').split('/').filter(p => p);
    const filename = pathParts.pop()!;

    let currentDir = this.directoryHandle;

    for (const dirName of pathParts) {
      currentDir = await currentDir.getDirectoryHandle(dirName);
    }

    return await currentDir.getFileHandle(`${filename}.json`);
  },

  /**
   * Retry import after auto-fixing the ID
   * This re-reads the file and sends it to the server
   */
  async retryImportWithCorrectedId(path: string, correctedId: string, originalChange: any): Promise<void> {
    console.log(`🔄 Retrying import for ${path} with corrected ID ${correctedId}`);

    // Re-read the note files (which now have the corrected ID)
    const noteFiles = await this.readNoteFiles(path.replace(/\.md$/, ''));

    if (!noteFiles) {
      console.error('Failed to re-read note files after auto-fix');
      return;
    }

    // Send to server again
    this.pushEvent('import_files', {
      changes: [{
        id: correctedId,
        version: noteFiles.version,
        name: noteFiles.metadata.name,
        tags: noteFiles.metadata.tags,
        data: noteFiles.metadata.data,
        markdown_content: noteFiles.markdown,
        path: path
      }]
    });
  },

  destroyed() {
    this.directoryHandle = null;
  }
};
