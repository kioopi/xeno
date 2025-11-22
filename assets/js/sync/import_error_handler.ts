/**
 * Handles import errors with auto-fixing capabilities
 *
 * This module implements the auto-healing mechanism for corrupted note IDs.
 * It decides whether to auto-fix based on agreement between server, local cache,
 * and JSON file, or whether to prompt the user for conflict resolution.
 */

import { noteMetadataStore } from '../stores/note_metadata_store';

export interface ImportError {
  type: string;
  message: string;
  provided_id?: string;
  suggested_id?: string;
  path?: string;
}

export interface AutoFixResult {
  action: 'auto_fixed' | 'user_prompt' | 'failed';
  correctedId?: string;
  reason?: string;
}

export interface ConflictOptions {
  filePath: string;
  jsonId: string;
  serverId: string;
  localId?: string;
  reason: string;
}

type AutoFixDecision = {
  action: 'auto_fix' | 'prompt';
  reason: string;
};

export class ImportErrorHandler {
  /**
   * Handle import error and attempt auto-fix if possible
   *
   * @param error - The error returned from the server
   * @param filePath - The path to the file being imported
   * @param onAutoFix - Callback to execute auto-fix (update JSON and retry)
   * @param onConflict - Callback to show conflict dialog and get user choice
   * @returns Result of the error handling attempt
   */
  async handleError(
    error: ImportError,
    filePath: string,
    onAutoFix: (correctedId: string) => Promise<void>,
    onConflict: (options: ConflictOptions) => Promise<string | null>
  ): Promise<AutoFixResult> {
    if (error.type !== 'id_not_found') {
      return { action: 'failed', reason: error.message };
    }

    const { provided_id, suggested_id, path } = error;

    if (!suggested_id) {
      return {
        action: 'failed',
        reason: `Note ID '${provided_id}' not found in database. This might be a deleted note.`
      };
    }

    const localMeta = await noteMetadataStore.getByPath(path!);

    const decision = this.decideAutoFix(provided_id!, suggested_id, localMeta?.id);

    switch (decision.action) {
      case 'auto_fix':
        console.log(`[Auto-fix] ${filePath}: ${decision.reason}`);
        await onAutoFix(suggested_id);
        return {
          action: 'auto_fixed',
          correctedId: suggested_id,
          reason: decision.reason
        };

      case 'prompt':
        const chosenId = await onConflict({
          filePath,
          jsonId: provided_id!,
          serverId: suggested_id,
          localId: localMeta?.id,
          reason: decision.reason
        });

        if (chosenId) {
          await onAutoFix(chosenId);
          return {
            action: 'auto_fixed',
            correctedId: chosenId,
            reason: 'User chose ID'
          };
        }

        return { action: 'failed', reason: 'User cancelled' };

      default:
        return { action: 'failed', reason: 'Unknown error' };
    }
  }

  /**
   * Decide whether to auto-fix or prompt user
   *
   * Decision matrix:
   * - No local metadata → trust server (new machine or cleared IndexedDB)
   * - Server and IndexedDB agree → auto-fix (corrupted JSON)
   * - All three disagree → prompt user
   */
  private decideAutoFix(
    jsonId: string,
    serverId: string,
    localId?: string
  ): AutoFixDecision {
    if (!localId) {
      return {
        action: 'auto_fix',
        reason: 'No local metadata, trusting server suggestion'
      };
    }

    if (localId === serverId) {
      return {
        action: 'auto_fix',
        reason: 'Server and local metadata agree, fixing corrupted JSON ID'
      };
    }

    return {
      action: 'prompt',
      reason: 'Conflicting IDs between JSON, server, and local cache'
    };
  }
}

export const importErrorHandler = new ImportErrorHandler();
