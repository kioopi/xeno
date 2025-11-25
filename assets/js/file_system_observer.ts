/**
 * FileSystemWatcher - Wrapper for FileSystemObserver API
 *
 * Watches a directory for file changes and triggers callbacks with debouncing.
 * This API is experimental and currently requires Chrome 129+ or Edge 129+.
 *
 * @see https://developer.chrome.com/docs/capabilities/web-apis/file-system-observer
 */

type ChangeCallback = (records: FileSystemChangeRecord[]) => void;

interface FileSystemChangeRecord {
  changedHandle: FileSystemHandle;
  relativePathComponents: string[];
  type: 'appeared' | 'disappeared' | 'modified' | 'errored' | 'unknown';
  root: FileSystemDirectoryHandle;
}

// Extend the global interface to include FileSystemObserver
declare global {
  interface FileSystemObserver {
    observe(handle: FileSystemDirectoryHandle, options?: { recursive?: boolean }): Promise<void>;
    unobserve(handle: FileSystemDirectoryHandle): void;
    disconnect(): void;
  }

  interface FileSystemObserverConstructor {
    new (callback: (records: FileSystemChangeRecord[], observer: FileSystemObserver) => void): FileSystemObserver;
  }

  const FileSystemObserver: FileSystemObserverConstructor | undefined;
}

export class FileSystemWatcher {
  private directoryHandle: FileSystemDirectoryHandle;
  private onChange: ChangeCallback;
  private observer: FileSystemObserver | null = null;
  private debounceTimer: number | null = null;
  private debounceDelay: number;
  private pendingChanges: FileSystemChangeRecord[] = [];

  /**
   * Creates a new FileSystemWatcher
   *
   * @param directoryHandle - The directory to watch
   * @param onChange - Callback function that receives change records
   * @param debounceDelay - Milliseconds to wait before processing changes (default: 500ms)
   */
  constructor(
    directoryHandle: FileSystemDirectoryHandle,
    onChange: ChangeCallback,
    debounceDelay: number = 500
  ) {
    this.directoryHandle = directoryHandle;
    this.onChange = onChange;
    this.debounceDelay = debounceDelay;
  }

  /**
   * Check if FileSystemObserver API is supported in the current browser
   */
  static isSupported(): boolean {
    return 'FileSystemObserver' in self;
  }

  /**
   * Start watching the directory for changes
   *
   * @throws Error if FileSystemObserver is not supported
   */
  async start(): Promise<void> {
    if (!FileSystemWatcher.isSupported()) {
      throw new Error('FileSystemObserver not supported in this browser');
    }

    this.observer = new FileSystemObserver((records) => {
      this.handleRecords(records);
    });

    await this.observer.observe(this.directoryHandle, {
      recursive: true
    });
  }

  /**
   * Stop watching the directory
   */
  stop(): void {
    if (this.debounceTimer !== null) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }

    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }

    this.pendingChanges = [];
  }

  /**
   * Handle file system change records with debouncing
   *
   * Batches rapid changes within the debounce window and calls onChange
   * when the window expires.
   */
  private handleRecords(records: FileSystemChangeRecord[]): void {
    // Add new records to pending changes
    this.pendingChanges.push(...records);

    // Clear existing timer
    if (this.debounceTimer !== null) {
      clearTimeout(this.debounceTimer);
    }

    // Set new timer
    this.debounceTimer = window.setTimeout(() => {
      // Process accumulated changes
      if (this.pendingChanges.length > 0) {
        const changesToProcess = [...this.pendingChanges];
        this.pendingChanges = [];
        this.onChange(changesToProcess);
      }

      this.debounceTimer = null;
    }, this.debounceDelay);
  }
}
