defmodule CarlosassistWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router: the page head, the site header and the site
  footer. The "app" layout is rendered as component in regular views
  and live views: the page's `<main>` and its flash messages.

  The look is one system for the whole app; its tokens and component
  classes are in `assets/css/app.css`.
  """
  use CarlosassistWeb, :html

  embed_templates "layouts/*"

  @doc """
  The page body: `<main>`, a centred container and the flash messages.

  `width` is the container's reading width: `"wide"` for dashboards,
  `"text"` for a single column, `"narrow"` for a short form.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :width, :string, default: "wide", values: ~w(wide text narrow)
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main id="main" class="site-main">
      <div class={[
        "wrap page",
        @width == "text" && "wrap-text",
        @width == "narrow" && "wrap-narrow"
      ]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  The site header: the mark and the name, then the account links.
  On a phone the links sit on their own row under the name.
  """
  attr :current_scope, :map, default: nil

  def site_header(assigns) do
    ~H"""
    <header class="site-header">
      <div class="wrap site-header-row">
        <.link href={~p"/"} class="brand" aria-label="CarlosAssist home">
          <img
            src={~p"/images/carlosassist-mark.webp"}
            alt=""
            width="48"
            height="48"
            class="brand-mark"
          />
          <span>
            <span class="brand-name">CarlosAssist</span>
            <span class="brand-line">Rides from parish volunteers</span>
          </span>
        </.link>

        <nav class="site-nav" aria-label="Account">
          <%= if @current_scope && @current_scope.user do %>
            <.link
              :if={@current_scope.user.role == "volunteer"}
              href={~p"/dashboard/volunteer"}
              class="site-nav-link"
            >
              Ride requests
            </.link>
            <.link
              :if={@current_scope.user.role != "volunteer"}
              href={~p"/dashboard/rider"}
              class="site-nav-link"
            >
              My rides
            </.link>
            <.link href={~p"/dashboard/inbox"} class="site-nav-link">Messages</.link>
            <.link href={~p"/users/settings"} class="site-nav-link">Settings</.link>
            <.link href={~p"/users/log-out"} method="delete" class="site-nav-link">
              Log out
            </.link>
          <% else %>
            <.link href={~p"/users/log-in"} class="site-nav-link">Log in</.link>
            <.link href={~p"/users/register"} class="site-nav-link">Register</.link>
          <% end %>
        </nav>
      </div>
    </header>
    """
  end

  @doc """
  The site footer: the ornament, one line about the service and the
  account links.
  """
  attr :current_scope, :map, default: nil

  def site_footer(assigns) do
    ~H"""
    <footer class="site-footer">
      <div class="wrap">
        <.divider class="mt-0" />
        <p class="text-xl italic">CarlosAssist</p>
        <p class="kicker mt-2">Rides given by parish volunteers</p>
        <nav
          :if={!(@current_scope && @current_scope.user)}
          class="site-footer-nav"
          aria-label="Footer"
        >
          <.link href={~p"/users/log-in"} class="link">Log in</.link>
          <.link href={~p"/users/register"} class="link">Create an account</.link>
        </nav>
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
    <div id={@id} class="flash-stack" aria-live="polite">
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
        <.icon name="hero-arrow-path" class="ml-1 size-5 motion-safe:animate-spin" />
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
        <.icon name="hero-arrow-path" class="ml-1 size-5 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
