# TypeScript Testing Guide

This project uses [Vitest](https://vitest.dev/) for TypeScript unit testing.

## Running Tests

```bash
cd assets

# Run tests in watch mode (recommended for development)
npm test

# Run tests with UI
npm run test:ui

# Run tests with coverage report
npm run test:coverage

# Run tests once (for CI)
npm test -- --run
```

## Writing Tests

### Test File Location

Place test files next to the code they're testing with a `.test.ts` or `.spec.ts` suffix:

```
js/
  utils/
    string_utils.ts
    string_utils.test.ts
  stores/
    note_metadata_store.ts
    note_metadata_store.test.ts
```

### Basic Test Structure

```typescript
import { describe, it, expect } from 'vitest';
import { myFunction } from './my_module';

describe('MyModule', () => {
  it('does something', () => {
    expect(myFunction()).toBe('expected');
  });
});
```

### Available Globals

Vitest provides these globals (no imports needed if you prefer):
- `describe`, `it`, `test`, `expect`
- `beforeEach`, `afterEach`, `beforeAll`, `afterAll`
- `vi` (for mocking)

### Testing Async Code

```typescript
it('handles async operations', async () => {
  const result = await fetchData();
  expect(result).toBeDefined();
});
```

### Mocking

```typescript
import { vi } from 'vitest';

it('mocks a function', () => {
  const mockFn = vi.fn(() => 'mocked');
  expect(mockFn()).toBe('mocked');
  expect(mockFn).toHaveBeenCalled();
});
```

### Testing IndexedDB

Vitest runs in `happy-dom` environment, which provides IndexedDB support:

```typescript
import { openDB } from 'idb';

it('works with IndexedDB', async () => {
  const db = await openDB('test-db', 1, {
    upgrade(db) {
      db.createObjectStore('store');
    }
  });

  await db.put('store', 'value', 'key');
  const result = await db.get('store', 'key');

  expect(result).toBe('value');
});
```

## Configuration

The test configuration is in `vitest.config.ts`. Key settings:

- **Environment**: `happy-dom` (lightweight DOM for testing)
- **Test pattern**: `js/**/*.{test,spec}.{js,ts}`
- **Alias**: `@` points to `./js` directory
- **Coverage**: Uses V8 provider

## Example Test

See `js/utils/string_utils.test.ts` for a complete example of:
- Multiple test suites with `describe`
- Individual test cases with `it`
- Various assertions with `expect`
- Edge case testing

## Tips

1. **Watch mode is fast**: Vitest only re-runs tests affected by your changes
2. **Use the UI**: `npm run test:ui` provides a visual test explorer
3. **Coverage reports**: Help identify untested code paths
4. **Mock sparingly**: Prefer testing real implementations when possible
5. **Test behavior, not implementation**: Focus on what the code does, not how

## Debugging Tests

```typescript
import { vi } from 'vitest';

it('debugs with console', () => {
  console.log('Debug info:', myValue);
  expect(myValue).toBe(expected);
});

it('uses vi.mock for dependencies', () => {
  vi.mock('./dependency', () => ({
    default: vi.fn(() => 'mocked'),
  }));
});
```

## CI Integration

For continuous integration, add to your pipeline:

```bash
cd assets && npm test -- --run --coverage
```

This runs tests once (no watch mode) and generates coverage reports.
