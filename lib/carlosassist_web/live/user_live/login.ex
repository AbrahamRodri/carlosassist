defmodule CarlosassistWeb.UserLive.Login do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts

  # Password sign-in: the main way in (`/users/log-in`)
  def render(%{live_action: :new} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg space-y-6">
        <div class="text-center">
          <h1 class="text-3xl sm:text-4xl text-base-content mb-2">Welcome back</h1>
          <span class="gold-rule mx-auto my-4"></span>
          <p class="text-lg text-base-content/75">
            <%= if @current_scope do %>
              For your safety, please confirm it's you before making changes to your account.
            <% else %>
              New here?
              <.link navigate={~p"/users/register"} class="link font-bold text-primary">
                Join us
              </.link>
              — it only takes a few minutes.
            <% end %>
          </p>
        </div>

        <.dev_mailbox_notice :if={local_mail_adapter?()} />

        <div class="parish-card p-6 sm:p-8">
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
              label="Your email address"
              placeholder="you@example.com"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Your password"
              autocomplete="current-password"
            />
            <.input
              :if={!@current_scope}
              field={f[:remember_me]}
              type="checkbox"
              label="Keep me signed in on this device"
            />
            <.button class="w-full btn-lg" variant="primary">
              Sign in
            </.button>
          </.form>
        </div>

        <p class="text-center text-lg text-base-content/75">
          Forgot your password, or never set one?
          <.link navigate={~p"/users/log-in/email"} class="link font-bold text-primary">
            Sign in with an emailed link instead
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  # Email-link sign-in: its own simple page (`/users/log-in/email`)
  def render(%{live_action: :magic} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg space-y-6">
        <div class="text-center">
          <h1 class="text-3xl sm:text-4xl text-base-content mb-2">Sign in by email</h1>
          <span class="gold-rule mx-auto my-4"></span>
          <p class="text-lg text-base-content/75">
            No password needed. Type your email address and we'll send you a link —
            just press it and you're in.
          </p>
        </div>

        <.dev_mailbox_notice :if={local_mail_adapter?()} />

        <div class="parish-card p-6 sm:p-8">
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
              label="Your email address"
              placeholder="you@example.com"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="w-full btn-lg" variant="primary">
              Email me a sign-in link
            </.button>
          </.form>
        </div>

        <p class="text-center text-lg text-base-content/75">
          <.link navigate={~p"/users/log-in"} class="link font-bold text-primary">
            Go back to regular sign in
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp dev_mailbox_notice(assigns) do
    ~H"""
    <div class="alert alert-info text-base">
      <.icon name="hero-information-circle" class="size-6 shrink-0" />
      <div>
        <p>You are running the local mail adapter.</p>
        <p>
          To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
        </p>
      </div>
    </div>
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
      "If that email is in our system, a sign-in link is on its way. Please open your email and press the link inside."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:carlosassist, Carlosassist.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
