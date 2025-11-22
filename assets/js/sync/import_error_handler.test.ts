import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ImportErrorHandler, ImportError, ConflictOptions } from './import_error_handler';
import { noteMetadataStore } from '../stores/note_metadata_store';

describe('ImportErrorHandler', () => {
  let handler: ImportErrorHandler;
  let mockAutoFix: ReturnType<typeof vi.fn>;
  let mockConflict: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    handler = new ImportErrorHandler();
    mockAutoFix = vi.fn();
    mockConflict = vi.fn();
    await noteMetadataStore.clear();
  });

  describe('handleError - auto-fix scenarios', () => {
    it('auto-fixes when server and IndexedDB agree (typo case)', async () => {
      await noteMetadataStore.upsert({
        id: 'correct-id-123',
        version: 5,
        path: 'projects/work/my-note',
        filename: 'my-note',
        lastSynced: new Date()
      });

      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'typo-id',
        suggested_id: 'correct-id-123',
        path: 'projects/work/my-note',
        message: 'Not found'
      };

      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'projects/work/my-note.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('auto_fixed');
      expect(result.correctedId).toBe('correct-id-123');
      expect(result.reason).toContain('Server and local metadata agree');
      expect(mockAutoFix).toHaveBeenCalledWith('correct-id-123');
      expect(mockConflict).not.toHaveBeenCalled();
    });

    it('auto-fixes on new machine (no IndexedDB entry)', async () => {
      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'some-id',
        suggested_id: 'server-id-456',
        path: 'notes/example',
        message: 'Not found'
      };

      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'notes/example.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('auto_fixed');
      expect(result.correctedId).toBe('server-id-456');
      expect(result.reason).toContain('No local metadata');
      expect(mockAutoFix).toHaveBeenCalledWith('server-id-456');
      expect(mockConflict).not.toHaveBeenCalled();
    });
  });

  describe('handleError - user prompt scenarios', () => {
    it('prompts user when IDs conflict (three-way disagreement)', async () => {
      await noteMetadataStore.upsert({
        id: 'local-id-789',
        version: 2,
        path: 'docs/conflict',
        filename: 'conflict',
        lastSynced: new Date()
      });

      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'json-id-abc',
        suggested_id: 'server-id-xyz',
        path: 'docs/conflict',
        message: 'Not found'
      };

      mockConflict.mockResolvedValue('server-id-xyz');
      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'docs/conflict.json',
        mockAutoFix,
        mockConflict
      );

      expect(mockConflict).toHaveBeenCalled();
      const conflictOptions: ConflictOptions = mockConflict.mock.calls[0][0];
      expect(conflictOptions.filePath).toBe('docs/conflict.json');
      expect(conflictOptions.jsonId).toBe('json-id-abc');
      expect(conflictOptions.serverId).toBe('server-id-xyz');
      expect(conflictOptions.localId).toBe('local-id-789');
      expect(conflictOptions.reason).toContain('Conflicting IDs');

      expect(mockAutoFix).toHaveBeenCalledWith('server-id-xyz');
      expect(result.action).toBe('auto_fixed');
      expect(result.correctedId).toBe('server-id-xyz');
    });

    it('returns failed when user cancels conflict resolution', async () => {
      await noteMetadataStore.upsert({
        id: 'local-id',
        version: 1,
        path: 'notes/cancel-test',
        filename: 'cancel-test',
        lastSynced: new Date()
      });

      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'json-id',
        suggested_id: 'server-id',
        path: 'notes/cancel-test',
        message: 'Not found'
      };

      mockConflict.mockResolvedValue(null);

      const result = await handler.handleError(
        error,
        'notes/cancel-test.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('failed');
      expect(result.reason).toBe('User cancelled');
      expect(mockAutoFix).not.toHaveBeenCalled();
    });
  });

  describe('handleError - error cases', () => {
    it('returns failed for non-id_not_found errors', async () => {
      const error: ImportError = {
        type: 'version_mismatch',
        message: 'Version conflict'
      };

      const result = await handler.handleError(
        error,
        'some/file.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('failed');
      expect(result.reason).toBe('Version conflict');
      expect(mockAutoFix).not.toHaveBeenCalled();
      expect(mockConflict).not.toHaveBeenCalled();
    });

    it('returns failed when no suggested_id provided', async () => {
      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'unknown-id',
        suggested_id: undefined,
        path: 'deleted/note',
        message: 'Not found'
      };

      const result = await handler.handleError(
        error,
        'deleted/note.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('failed');
      expect(result.reason).toContain('not found in database');
      expect(result.reason).toContain('deleted note');
      expect(mockAutoFix).not.toHaveBeenCalled();
      expect(mockConflict).not.toHaveBeenCalled();
    });
  });

  describe('decideAutoFix logic', () => {
    it('decides auto-fix when no local metadata exists', async () => {
      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'wrong-id',
        suggested_id: 'correct-id',
        path: 'new/note',
        message: 'Not found'
      };

      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'new/note.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('auto_fixed');
      expect(result.reason).toContain('No local metadata');
    });

    it('decides auto-fix when server and local IDs match', async () => {
      await noteMetadataStore.upsert({
        id: 'matching-id',
        version: 1,
        path: 'match/test',
        filename: 'test',
        lastSynced: new Date()
      });

      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'typo',
        suggested_id: 'matching-id',
        path: 'match/test',
        message: 'Not found'
      };

      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'match/test.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('auto_fixed');
      expect(result.reason).toContain('agree');
    });

    it('decides prompt when server and local IDs differ', async () => {
      await noteMetadataStore.upsert({
        id: 'local-different',
        version: 1,
        path: 'conflict/path',
        filename: 'path',
        lastSynced: new Date()
      });

      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'json-id',
        suggested_id: 'server-different',
        path: 'conflict/path',
        message: 'Not found'
      };

      mockConflict.mockResolvedValue('server-different');
      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'conflict/path.json',
        mockAutoFix,
        mockConflict
      );

      expect(mockConflict).toHaveBeenCalled();
      expect(result.action).toBe('auto_fixed');
    });
  });

  describe('integration with real noteMetadataStore', () => {
    it('correctly queries IndexedDB by path', async () => {
      await noteMetadataStore.upsert({
        id: 'test-id-123',
        version: 10,
        path: 'integration/test',
        filename: 'test',
        lastSynced: new Date()
      });

      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'bad-id',
        suggested_id: 'test-id-123',
        path: 'integration/test',
        message: 'Not found'
      };

      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'integration/test.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('auto_fixed');
      expect(mockAutoFix).toHaveBeenCalledWith('test-id-123');
    });

    it('handles missing IndexedDB entry gracefully', async () => {
      const error: ImportError = {
        type: 'id_not_found',
        provided_id: 'some-id',
        suggested_id: 'suggested',
        path: 'nonexistent/path',
        message: 'Not found'
      };

      mockAutoFix.mockResolvedValue(undefined);

      const result = await handler.handleError(
        error,
        'nonexistent/path.json',
        mockAutoFix,
        mockConflict
      );

      expect(result.action).toBe('auto_fixed');
      expect(result.reason).toContain('No local metadata');
    });
  });
});
