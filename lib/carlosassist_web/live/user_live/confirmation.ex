defmodule CarlosassistWeb.UserLive.Confirmation do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} width="narrow">
      <div class="sheet">
        <.header kicker="Welcome">
          <span class="break-words">{@user.email}</span>
          <:subtitle :if={!@user.confirmed_at}>
            Press the button to confirm your account and log in.
          </:subtitle>
          <:subtitle :if={@user.confirmed_at}>
            Press the button to log in.
          </:subtitle>
        </.header>

        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.input
            :if={!@current_scope}
            field={@form[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />
          <.button variant="primary" phx-disable-with="Confirming..." class="btn-block">
            Confirm my account
          </.button>
        </.form>

        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <.input
            :if={!@current_scope}
            field={@form[:remember_me]}
            type="checkbox"
            label="Keep me logged in"
          />
          <.button variant="primary" phx-disable-with="Logging in..." class="btn-block">
            Log in
          </.button>
        </.form>

        <div :if={!@user.confirmed_at} class="notice mt-8">
          <.icon name="hero-information-circle" />
          <p>If you would rather use a password, you can set one in Settings.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
