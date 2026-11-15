defmodule CarlosassistWeb.UserLive.Login do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} width="narrow">
      <div class="sheet">
        <.header kicker="Welcome back">
          Log in
          <:subtitle>
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Do not have an account yet?
              <.link navigate={~p"/users/register"} class="link link-inline">Sign up</.link>
            <% end %>
          </:subtitle>
        </.header>

        <div :if={local_mail_adapter?()} class="notice mb-6">
          <.icon name="hero-information-circle" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="link link-inline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <h2 class="card-title mb-1">Get a link by email</h2>
        <p class="muted small mb-4">
          No password needed. We send a link to your email, and the link logs you in.
        </p>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn-block" variant="primary">
            Log in with email <.icon name="hero-arrow-right" class="size-6" />
          </.button>
        </.form>

        <.divider class="my-8" />

        <h2 class="card-title mb-1">Or use your password</h2>
        <p class="muted small mb-4">If you have set a password, enter it here.</p>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
          />
          <.input
            :if={!@current_scope}
            field={f[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />
          <.button class="btn-block">
            Log in
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:carlosassist, Carlosassist.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
