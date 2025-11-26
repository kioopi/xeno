# Xeno

A note-taking application built with Phoenix LiveView and Ash Framework.

## Getting Started

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `bin/server` (recommended) or `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Features

### File System Sync

Edit your notes in external editors like VS Code, Vim, or any text editor of your choice. Changes are automatically synced back to the database.

* **Manual Export/Import**: Export notes to a local folder and import changes with a click
* **Auto-Sync**: Automatically import changes when you save files (Chrome 129+/Edge 129+)
* **Conflict Resolution**: Optimistic locking prevents accidental overwrites
* **Persistent Connection**: Your selected folder is remembered across browser sessions

See [`docs/filesystem-sync.md`](docs/filesystem-sync.md) for complete documentation, browser compatibility, and usage instructions.

## Development Workflow

### Starting the Server

Use the provided script to start the server with remote console support:

```bash
bin/server
```

This starts Phoenix with a named Erlang node, allowing you to connect remote consoles.

### Remote Console

To connect an IEx console to the running server (for debugging, creating data, etc.):

```bash
bin/console
```

This connects to the same Erlang VM as the server, so:

* Any data you create will immediately appear in the browser via LiveView
* You can inspect running processes and application state
* PubSub messages are shared between the server and console

**Tip**: Keep the server running in one terminal and use the console in another
terminal for the best development experience.

### Running Tests

#### Elixir Tests

Run the Elixir test suite:

```bash
mix test
```

For specific tests:

```bash
# Run a specific test file
mix test test/xeno/sync/importer_test.exs

# Run tests matching a pattern
mix test --only tag_name
```

#### TypeScript Tests

Run the TypeScript/JavaScript test suite:

```bash
cd assets
npm test              # Watch mode (re-runs on file changes)
npm test -- --run     # Run once
npm run test:ui       # Interactive UI
npm run test:coverage # With coverage report
```

See [`docs/typescript-setup.md`](docs/typescript-setup.md) for more details on the TypeScript setup.

### Alternative: Single Terminal

If you prefer a single terminal, start with:

```bash
iex -S mix phx.server
```

You can create additional IEx shells within the same session:

1. Press `Ctrl+G`
2. Type `s` + Enter to start a new shell
3. Type `c <number>` + Enter to switch between shells

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: <https://www.phoenixframework.org/>
* Guides: <https://hexdocs.pm/phoenix/overview.html>
* Docs: <https://hexdocs.pm/phoenix>
* Forum: <https://elixirforum.com/c/phoenix-forum>
* Source: <https://github.com/phoenixframework/phoenix>
