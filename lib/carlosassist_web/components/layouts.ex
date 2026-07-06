defmodule CarlosassistWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use CarlosassistWeb, :html

  embed_templates "layouts/*"

  def app(assigns) do
    ~H"""
    <main class="flex-1">
      <div class="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-8">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  The CarlosAssist brand mark: a Sacred Heart with a small gold cross rising
  from its crown, and a road winding through it — love that drives.
  Sized via `class`.
  """
  attr :class, :string, default: "w-10 h-10"

  def brand_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 48 54" fill="none" xmlns="http://www.w3.org/2000/svg" class={@class} aria-hidden="true">
      <!-- gold cross standing at the heart's crown -->
      <path d="M24 1v13M19.5 5.5h9" stroke="#d4af37" stroke-width="3" stroke-linecap="round" />
      <!-- the heart -->
      <path
        d="M24 49C11.5 39.5 4 31 4 20.8 4 14 9.2 8.8 15.8 8.8c3.4 0 6.4 1.6 8.2 4.4 1.8-2.8 4.8-4.4 8.2-4.4C38.8 8.8 44 14 44 20.8 44 31 36.5 39.5 24 49Z"
        class="fill-primary"
      />
      <!-- road: enters at the dip beneath the cross, winds out the bottom point -->
      <path
        d="M24 13.5c-1 4 3.5 6.5 1.5 12s-5 7.5-3 12 2.5 7 1.5 11"
        stroke="#faf6ef"
        stroke-width="4.5"
        stroke-linecap="round"
        fill="none"
      />
      <!-- dashed gold center line -->
      <path
        d="M24 13.5c-1 4 3.5 6.5 1.5 12s-5 7.5-3 12 2.5 7 1.5 11"
        stroke="#d4af37"
        stroke-width="1.2"
        stroke-dasharray="3.5 4"
        stroke-linecap="round"
        fill="none"
      />
    </svg>
    """
  end

  @doc """
  Shared footer: brand lockup, one line of scripture, and the St. Christopher
  dedication — the app's quiet Catholic thread.
  """
  def footer(assigns) do
    ~H"""
    <footer class="mt-16 border-t-2 border-base-300 bg-base-200">
      <div class="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-10 text-center">
        <div class="flex items-center justify-center gap-3 mb-4">
          <.brand_mark class="w-8 h-9" />
          <span class="font-display text-2xl text-base-content">CarlosAssist</span>
        </div>
        <p class="font-display italic text-lg text-base-content/80">
          “Carry one another's burdens.”
        </p>
        <p class="text-base text-base-content/70 mb-6">— Galatians 6:2</p>
        <p class="text-base text-base-content/70">
          A volunteer ride ministry, offered with care by your parish community.
        </p>
        <p class="mt-2 text-base text-base-content/60">
          Under the patronage of St. Christopher, patron of travelers.
        </p>
      </div>
    </footer>
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
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
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
    <div class="flex flex-wrap gap-2" role="group" aria-label="Screen appearance">
      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="btn btn-outline [[data-theme=light]_&]:btn-primary"
      >
        <.icon name="hero-sun" class="size-5" /> Light
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="btn btn-outline [[data-theme=dark]_&]:btn-primary"
      >
        <.icon name="hero-moon" class="size-5" /> Dark
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="btn btn-outline"
      >
        <.icon name="hero-computer-desktop" class="size-5" /> Match my device
      </button>
    </div>
    """
  end
end
