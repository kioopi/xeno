# Debugging Sync Issues

## Quick Debugging Checklist

When sync fails, check these in order:

### 1. **Browser Console** (Most Important!)
Open DevTools → Console tab. You'll see:

```
🔍 Scanning files for changes...
📤 Sending changes to server
  Total changes: 2
  Change 1: {id: "abc-123", path: "note1", version: 1, ...}
  Change 2: {id: "def-456", path: "note2", version: undefined, ...}

📥 Import Results
  Total results: 2
  ✅ Success: {note_id: "abc-123", new_version: 2}
  ❌ Error: {type: "id_not_found", message: "...", details: {...}}
```

**What to look for:**
- ✅ **Success logs:** Note imported correctly, version incremented
- ❌ **Error logs:** Shows exact error type and details
- 💡 **ID Not Found:** JSON file has wrong ID (look for suggested_id)
- ⚠️ **Path Mismatch:** Note moved but ID points to old location

### 2. **IndexedDB** (Check Version Tracking)
DevTools → Application tab → IndexedDB → `xeno-note-metadata` → `metadata`

**Expected structure:**
```json
{
  "id": "abc-123",
  "version": 1,
  "path": "projects/work/my-note",
  "filename": "my-note",
  "lastSynced": "2025-11-24T..."
}
```

**Common issues:**
- ❌ Empty database → First import on new machine (versions will be undefined)
- ❌ Stale version → Clear IndexedDB and re-export to reset
- ❌ Wrong path → Note was moved, needs path update

### 3. **JSON File Format** (Check File Structure)
Open the `.json` file in your export folder:

**✅ Correct format (NEW):**
```json
{
  "_schema_version": "1.0",
  "_id": "abc-123",
  "_note": "Fields prefixed with _ are system-generated...",
  "name": "My Note",
  "tags": ["tag1"],
  "data": {}
}
```

**❌ Wrong format (OLD):**
```json
{
  "id": "abc-123",          // Missing underscore!
  "version": 1,             // Should NOT be in JSON
  "name": "My Note",
  "note_type_id": "xyz"     // Should NOT be in JSON
}
```

### 4. **LiveView Flash Messages**
Look at the top of the page for flash messages:
- `Successfully imported 2 note(s)` → All good ✅
- `Imported 1, failed 1` → Check console for error details ❌

### 5. **Server Logs** (Terminal where `mix phx.server` runs)
Look for Elixir errors or Ash validation failures:
```
[error] #Ecto.Query.CastError<...>
[error] #Ash.Error.Invalid{...}
```

---

## Common Error Scenarios

### Error: "2 notes failed" with no details

**Cause:** `import_result` event not being handled

**Solution:** ✅ FIXED - Added `handleImportResult` handler that logs to console

**How to verify:**
1. Click "Import Changes"
2. Open console
3. Should see `📥 Import Results` with detailed error logs

---

### Error: `id_not_found` with `suggested_id`

**Console output:**
```
❌ Error: {type: "id_not_found", ...}
💡 ID Not Found - Suggested fix:
   provided_id: "abc-wrong"
   suggested_id: "abc-correct"
   path: "my-note"
```

**Causes:**
1. Typo in JSON `_id` field
2. Manually edited ID incorrectly
3. Copied note from different database

**Manual fix:**
1. Open `.json` file
2. Change `_id` to the `suggested_id` from console
3. Save and re-import

**Future:** Auto-fix will do this automatically

---

### Error: `path_mismatch`

**Console output:**
```
❌ Error: {type: "path_mismatch", ...}
⚠️ Path Mismatch:
   note_id: "abc-123"
   expected: "old/path/note.md"
   actual: "new/path/note"
```

**Common Causes:**

1. **Path format mismatch** (FIXED 2025-11-24):
   - Database stores: `til/note_2.md` (with extension)
   - Filesystem sends: `til/note_2` (without extension)
   - **Solution:** ✅ Fixed in scanDirectory to append `.md`

2. **Note actually moved:**
   - File physically moved to different directory
   - Database still points to old location
   - **Solutions:**
     - Move file back to expected location
     - Update database path (not yet implemented)
     - Delete and re-create note with new path

---

### Error: Version mismatch / stale record

**Console output:**
```
❌ Error: {type: "unknown", message: "stale record..."}
```

**Cause:** IndexedDB has old version number

**Solutions:**
1. Clear IndexedDB:
   - DevTools → Application → IndexedDB → Right-click `xeno-note-metadata` → Delete
2. Re-export all notes to repopulate IndexedDB
3. Import should now work

---

### Error: "Invalid UUID format"

**Console output:**
```
❌ Error: {type: "unknown", message: "Invalid UUID..."}
```

**Cause:** `_id` field is not a valid UUID

**Solution:**
1. Check JSON file `_id` field
2. Must be format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
3. Fix manually or regenerate via export

---

## Debugging Workflow

### For Users (Manual Testing):

1. **Clear state** (fresh start):
   ```bash
   # In browser DevTools console:
   indexedDB.deleteDatabase('xeno-note-metadata')
   ```

2. **Export notes** → Check:
   - Files created ✅
   - IndexedDB populated ✅
   - JSON format correct ✅

3. **Edit .md file** → Import → Check console:
   - Scanned changes ✅
   - Import results ✅
   - Errors logged ❌ (if any)

4. **Check flash message** → Should show success count

### For Developers (Adding Features):

1. **Add console.log** at key points:
   ```typescript
   console.group('🔍 My Feature');
   console.log('Input:', data);
   console.log('Result:', result);
   console.groupEnd();
   ```

2. **Use console groups** for nested operations:
   ```typescript
   console.group('📤 Parent Operation');
   console.log('Step 1...');
   console.group('  🔸 Child Operation');
   console.log('Detail...');
   console.groupEnd();
   console.groupEnd();
   ```

3. **Log errors with context**:
   ```typescript
   catch (error) {
     console.error('❌ Operation failed:', {
       context: 'what was happening',
       input: inputData,
       error: error.message,
       stack: error.stack
     });
   }
   ```

---

## Future Improvements

### Logging Infrastructure
- [ ] Add log levels (DEBUG, INFO, WARN, ERROR)
- [ ] Configurable logging (disable in production)
- [ ] Structured logging with timestamps
- [ ] Log aggregation to server

### Error Reporting
- [ ] Show detailed errors in UI (not just flash message)
- [ ] Error toast notifications with actions
- [ ] Error details modal with copy-to-clipboard
- [ ] Automatic error reporting to developer

### Developer Tools
- [ ] Debug mode toggle in UI
- [ ] Export diagnostic report (logs + IndexedDB + JSON samples)
- [ ] Visual diff tool for version conflicts
- [ ] Sync history viewer

### Automated Testing
- [ ] E2E tests for full sync cycle
- [ ] Automated error scenario tests
- [ ] Performance monitoring (import speed)
- [ ] Regression test suite

---

## Current Debug Features (2025-11-24)

✅ **Implemented:**
- Console logging for scan results
- Console logging for import results
- Error type detection with helpful context
- Detailed error information (provided_id, suggested_id, paths)
- Grouped console output for readability

✅ **Working:**
- Export → IndexedDB population
- Import → Version lookup from IndexedDB
- Error formatting from backend
- Event communication (LiveView ↔ Hook)

⏳ **TODO:**
- Auto-fix for ID mismatches
- IndexedDB version update after successful import
- UI display of individual file errors
- Path update support for moved notes
