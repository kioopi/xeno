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

interface FileToWrite {
  path: string;
  markdown: string;
  json: string;
}

interface WriteFilesPayload {
  files: FileToWrite[];
}

interface LiveViewHook {
  pushEvent(event: string, payload: Record<string, any>): void;
  handleEvent(event: string, callback: (payload: any) => void): void;
}

export const FileSystemHook: LiveViewHook & {
  mounted(this: LiveViewHook): void;
  destroyed(this: LiveViewHook): void;
  directoryHandle: FileSystemDirectoryHandle | null;
  handleStore: DirectoryHandleStore;
} = {
  directoryHandle: null,
  handleStore: null as any,

  mounted() {
    this.directoryHandle = null;
    this.handleStore = new DirectoryHandleStore();

    this.handleEvent('request_directory', this.requestDirectory.bind(this));
    this.handleEvent('write_files', this.writeFiles.bind(this));
    this.handleEvent('disconnect_directory', this.disconnectDirectory.bind(this));
    this.handleEvent('scan_files', this.scanFiles.bind(this));

    this.loadPersistedHandle();
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

    const mdHandle = await currentDir.getFileHandle(`${baseFilename}.md`, { create: true });
    const mdWritable = await mdHandle.createWritable();
    await mdWritable.write(file.markdown);
    await mdWritable.close();

    const jsonHandle = await currentDir.getFileHandle(`${baseFilename}.json`, { create: true });
    const jsonWritable = await jsonHandle.createWritable();
    await jsonWritable.write(file.json);
    await jsonWritable.close();
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
        this.pushEvent('import_error', {
          message: 'Permission denied. Please reconnect the folder.'
        });
        return;
      }

      const changes = await this.scanForChanges();

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

  async readNoteFiles(path: string): Promise<{markdown: string, metadata: any} | null> {
    try {
      const pathParts = path.split('/').filter(p => p);
      const filename = pathParts.pop()!;

      let currentDir = this.directoryHandle!;

      for (const dirName of pathParts) {
        currentDir = await currentDir.getDirectoryHandle(dirName);
      }

      const baseFilename = filename.replace(/\.[^/.]+$/, '');

      const mdHandle = await currentDir.getFileHandle(`${baseFilename}.md`);
      const mdFile = await mdHandle.getFile();
      const markdown = await mdFile.text();

      const jsonHandle = await currentDir.getFileHandle(`${baseFilename}.json`);
      const jsonFile = await jsonHandle.getFile();
      const jsonText = await jsonFile.text();
      const metadata = JSON.parse(jsonText);

      return {markdown, metadata};
    } catch (error) {
      console.error(`Error reading note files at ${path}:`, error);
      return null;
    }
  },

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

  async scanDirectory(dirHandle: FileSystemDirectoryHandle, currentPath: string, changes: any[]): Promise<void> {
    for await (const entry of dirHandle.values()) {
      const entryPath = currentPath ? `${currentPath}/${entry.name}` : entry.name;

      if (entry.kind === 'directory') {
        await this.scanDirectory(entry as FileSystemDirectoryHandle, entryPath, changes);
      } else if (entry.kind === 'file' && entry.name.endsWith('.md')) {
        const baseName = entry.name.replace(/\.md$/, '');
        const filePath = currentPath ? `${currentPath}/${baseName}` : baseName;

        const noteFiles = await this.readNoteFiles(filePath);

        if (noteFiles && noteFiles.metadata && noteFiles.metadata.id) {
          changes.push({
            note_id: noteFiles.metadata.id,
            markdown_content: noteFiles.markdown,
            metadata: noteFiles.metadata
          });
        }
      }
    }
  },

  destroyed() {
    this.directoryHandle = null;
  }
};
