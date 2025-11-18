# Xeno

A note-taking application built with Phoenix LiveView and Ash Framework.

## Getting Started

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `bin/server` (recommended) or `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

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
