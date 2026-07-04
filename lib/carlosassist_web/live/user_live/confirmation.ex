defmodule CarlosassistWeb.UserLive.Confirmation do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg text-center">
        <h1 class="text-3xl sm:text-4xl text-base-content mb-2">
          Welcome, {Carlosassist.Accounts.User.first_name(@user)}!
        </h1>
        <span class="gold-rule mx-auto my-4"></span>
        <p class="text-lg text-base-content/75 mb-8">
          <%= if @user.confirmed_at do %>
            Press the button below and you'll be signed in.
          <% else %>
            One last step — press the button below to finish setting up your account.
          <% end %>
        </p>

        <div class="parish-card p-6 sm:p-8">
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
              label="Keep me signed in on this device"
            />
            <.button variant="primary" phx-disable-with="One moment..." class="w-full btn-lg">
              Finish signing up
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
              label="Keep me signed in on this device"
            />
            <.button variant="primary" phx-disable-with="One moment..." class="w-full btn-lg">
              Sign me in
            </.button>
          </.form>
        </div>

        <p :if={!@user.confirmed_at} class="mt-6 text-base text-base-content/70">
          Tip: if you'd rather sign in with a password, you can set one up later
          under <strong>My Account</strong>.
        </p>
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
