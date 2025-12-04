defmodule XenoWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use XenoWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <.icon name="note-sticky" variant={:regular} /> ζήνω
        </a>
      </div>
      <div class="flex-none">
        <nav
          aria-label="Footer"
          class="-mb-6 flex flex-wrap justify-center gap-x-12 gap-y-3 text-sm/6"
        >
          <.link
            navigate={~p"/notes/new"}
            class="text-slate-900 hover:underline hover:text-slate-600 dark:text-gray-400 dark:hover:text-white"
          >
            Create Note
          </.link>
          <.link
            navigate={~p"/info"}
            class="text-slate-900 hover:underline hover:text-slate-600 dark:text-gray-400 dark:hover:text-white"
          >
            Info
          </.link>
          <.link
            navigate={~p"/sync"}
            class="text-slate-900 hover:underline hover:text-slate-600 dark:text-gray-400 dark:hover:text-white"
          >
            Sync
          </.link>
        </nav>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer>
      <div class="mx-auto max-w-7xl overflow-hidden px-6 py-20 sm:py-24 lg:px-8">
        <nav
          aria-label="Footer"
          class="-mb-6 flex flex-wrap justify-center gap-x-12 gap-y-3 text-sm/6"
        >
          <a
            href="https://phoenixframework.org/"
            class="text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
          >
            <.icon name="phoenix-framework" family="brands" /> Phoenix
            <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
          </a>

          <a
            href="https://hexdocs.pm/phoenix/overview.html"
            class="text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
          >
            <wa-icon src="https://hexdocs.pm/images/hexdocs-logo.svg" class="grayscale"></wa-icon>
            Phoenix Docs
          </a>

          <a
            href="https://github.com/kioopi/xeno"
            class="text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
          >
            <.icon name="github" family="brands" /> Xeno
          </a>

          <.theme_toggle />
        </nav>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <label
      class="swap swap-rotate text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
      id="theme-toggle"
    >
      <.theme_button theme="dark" icon="sun" swap="on" />
      <.theme_button theme="light" icon="moon" swap="off" />
    </label>
    """
  end

  attr :theme, :string, required: true, values: ["light", "dark"]
  attr :icon, :string, default: "sun"
  attr :swap, :string, required: true, values: ["on", "off"]

  def theme_button(assigns) do
    ~H"""
    <button
      phx-click={JS.dispatch("phx:set-theme")}
      data-phx-theme={@theme}
      class={["swap-" <> @swap, "h-auto"]}
    >
      <wa-icon
        name={@icon}
        variant={:regular}
        label="Choose dark theme"
      >
      </wa-icon>
    </button>
    """
  end
end
