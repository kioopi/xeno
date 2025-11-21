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

export const FileSystemHook = {
  mounted() {
    this.directoryHandle = null;
    this.handleStore = new DirectoryHandleStore();

    this.handleEvent('request_directory', this.requestDirectory.bind(this));
    this.handleEvent('write_files', this.writeFiles.bind(this));
    this.handleEvent('disconnect_directory', this.disconnectDirectory.bind(this));

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
    } catch (error) {
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
   * @param {Object} payload - Contains files array with path, markdown, json
   */
  async writeFiles(payload) {
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
    } catch (error) {
      console.error('Error writing files:', error);
      this.pushEvent('export_error', {
        message: error.message || 'Failed to write files'
      });
    }
  },

  /**
   * Write markdown and JSON files for a single note
   * @param {Object} file - Contains path, markdown, json, metadata
   */
  async writeNoteFiles(file) {
    const pathParts = file.path.split('/');
    const filename = pathParts.pop();

    let currentDir = this.directoryHandle;

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

  destroyed() {
    this.directoryHandle = null;
  }
};
