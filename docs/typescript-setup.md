# TypeScript Setup

This document describes the TypeScript setup for the Xeno project frontend.

## Overview

The frontend uses TypeScript for type safety and better developer experience. The setup is minimal and focused, using modern tooling that integrates seamlessly with Phoenix and esbuild.

## Build System

### esbuild

The project uses [esbuild](https://esbuild.github.io/) for bundling and compiling TypeScript to JavaScript. Configuration is in `config/config.exs`:

```elixir
config :esbuild,
  version: "0.25.4",
  xeno: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js ...),
    cd: Path.expand("../assets", __DIR__),
    ...
  ]
```

**Key points:**
- esbuild compiles TypeScript natively (no separate tsc step needed)
- Target: ES2022 (modern browsers)
- Entry point: `assets/js/app.js`
- Output: `priv/static/assets/js/`

### Phoenix Integration

Phoenix's built-in watchers automatically rebuild TypeScript files during development:

```bash
# Start Phoenix server with live reloading
mix phx.server
```

This triggers esbuild on file changes, providing instant feedback.

## TypeScript Configuration

Configuration file: `assets/tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "lib": ["ES2022", "DOM"],
    "moduleResolution": "bundler",
    "strict": true,
    "noEmit": true,
    ...
  },
  "include": ["js/**/*"],
  "exclude": ["node_modules"]
}
```

### Compiler Options Explained

| Option | Value | Reason |
|--------|-------|--------|
| `target` | ES2022 | Modern JavaScript features |
| `module` | ESNext | Native ES modules |
| `lib` | ES2022, DOM | Standard library + browser APIs |
| `moduleResolution` | bundler | Works with esbuild's bundler |
| `strict` | true | Maximum type safety |
| `noEmit` | true | esbuild handles compilation |
| `allowJs` | true | Can import .js files |

### Path Aliases

The `@` alias maps to the `js/` directory for cleaner imports:

```typescript
// Instead of this:
import { foo } from '../../../utils/helpers';

// You can write:
import { foo } from '@/utils/helpers';
```

## Project Structure

```
assets/
├── js/
│   ├── app.js              # Main entry point
│   ├── hooks/              # LiveView hooks
│   │   └── file_system_hook.ts
│   ├── stores/             # Data stores (IndexedDB, etc)
│   ├── sync/               # File sync logic
│   └── utils/              # Utility functions
│       ├── string_utils.ts
│       └── string_utils.test.ts
├── css/                    # Stylesheets
├── tsconfig.json           # TypeScript config
├── vitest.config.ts        # Test config
├── package.json            # Dependencies
└── TESTING.md              # Testing guide
```

## Type Checking

TypeScript type checking is **separate from compilation**. esbuild compiles TypeScript but doesn't do full type checking.

### Editor Integration

Most editors (VS Code, Neovim, etc.) automatically type-check using `tsconfig.json`. You'll see errors inline as you code.

### Manual Type Checking

```bash
cd assets
npx tsc --noEmit
```

This runs the TypeScript compiler in check-only mode (no files emitted).

### CI Integration

Add to your CI pipeline for pre-deployment type checking:

```bash
cd assets && npx tsc --noEmit
```

## Testing

The project uses [Vitest](https://vitest.dev/) for unit testing TypeScript code.

### Quick Start

```bash
cd assets

# Run tests (watch mode)
npm test

# Run tests once
npm test -- --run

# Run with UI
npm run test:ui

# Generate coverage
npm run test:coverage
```

### Test File Conventions

- Place tests next to source files
- Use `.test.ts` or `.spec.ts` suffix
- Example: `string_utils.ts` → `string_utils.test.ts`

See [`assets/TESTING.md`](../assets/TESTING.md) for detailed testing documentation.

## Working with Phoenix LiveView

### LiveView Hooks

TypeScript can be used for Phoenix LiveView hooks:

```typescript
// assets/js/hooks/my_hook.ts
export const MyHook = {
  mounted() {
    console.log('Hook mounted!');
  },

  updated() {
    console.log('Hook updated!');
  },

  destroyed() {
    console.log('Hook destroyed!');
  }
};
```

Register in `app.js`:

```javascript
import { MyHook } from './hooks/my_hook';

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { MyHook }
});
```

### Type Definitions

For LiveView hooks and Phoenix types, you can create custom type definitions:

```typescript
// assets/js/types/phoenix.d.ts
interface LiveViewHook {
  mounted?(): void;
  updated?(): void;
  destroyed?(): void;
  pushEvent(event: string, payload: Record<string, any>): void;
  handleEvent(event: string, callback: (payload: any) => void): void;
}
```

## Dependencies

### Installing Packages

```bash
cd assets
npm install <package-name>
```

For type definitions:

```bash
npm install -D @types/<package-name>
```

### Current Dependencies

**Runtime:**
- `@awesome.me/webawesome` - Web components library

**Development:**
- `vitest` - Testing framework
- `@vitest/ui` - Test UI
- `happy-dom` - DOM environment for tests

## Browser API Support

The project targets modern browsers with native support for:

- **ES2022 features** (async/await, optional chaining, etc.)
- **ES Modules** (import/export)
- **DOM APIs** (standard browser APIs)
- **File System Access API** (for local file sync)

### IndexedDB

IndexedDB is used for client-side storage. We recommend the [`idb`](https://github.com/jakearchibald/idb) library for a better developer experience:

```bash
npm install idb
```

```typescript
import { openDB } from 'idb';

const db = await openDB('my-database', 1, {
  upgrade(db) {
    db.createObjectStore('notes');
  }
});

await db.put('notes', { id: '123', text: 'Hello' }, '123');
const note = await db.get('notes', '123');
```

## Code Quality

### Linting

Currently, no linter is configured. To add ESLint:

```bash
cd assets
npm install -D eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

### Formatting

For consistent code formatting, consider adding Prettier:

```bash
cd assets
npm install -D prettier
```

## Debugging

### Browser DevTools

TypeScript source maps are generated automatically by esbuild, allowing you to debug TypeScript code directly in browser DevTools.

### Console Logging

```typescript
console.log('Debug value:', myVariable);
console.error('Error occurred:', error);
```

### Breakpoints

Set breakpoints in your browser's DevTools on the TypeScript source (not compiled JavaScript).

## Production Builds

For production deployment:

```bash
MIX_ENV=prod mix assets.deploy
```

This:
1. Compiles TypeScript → JavaScript via esbuild
2. Minifies the output
3. Generates cache digests
4. Optimizes assets for production

## Common Patterns

### Async/Await

```typescript
async function fetchData(): Promise<Data> {
  const response = await fetch('/api/data');
  return response.json();
}
```

### Type Guards

```typescript
function isString(value: unknown): value is string {
  return typeof value === 'string';
}

if (isString(input)) {
  // TypeScript knows input is string here
  console.log(input.toUpperCase());
}
```

### Generics

```typescript
function firstElement<T>(arr: T[]): T | undefined {
  return arr[0];
}

const num = firstElement([1, 2, 3]); // number | undefined
const str = firstElement(['a', 'b']); // string | undefined
```

## Troubleshooting

### Module not found

If TypeScript can't find a module:

1. Check the import path is correct
2. Ensure the file has a `.ts` or `.js` extension
3. Verify `tsconfig.json` includes the file
4. Restart your editor's TypeScript server

### Type errors in node_modules

Add to `tsconfig.json`:

```json
{
  "compilerOptions": {
    "skipLibCheck": true
  }
}
```

### Build errors

If esbuild fails to compile:

1. Check the error message in terminal
2. Verify TypeScript syntax is valid
3. Ensure all imports resolve correctly
4. Try `rm -rf _build && mix phx.server`

## Resources

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [esbuild Documentation](https://esbuild.github.io/)
- [Vitest Documentation](https://vitest.dev/)
- [Phoenix LiveView Docs](https://hexdocs.pm/phoenix_live_view/)

## Getting Help

- Check TypeScript compiler errors carefully (they're usually helpful!)
- Use your editor's "Go to Definition" feature
- Read type definitions in `node_modules/@types/`
- Ask in Phoenix or TypeScript community forums
