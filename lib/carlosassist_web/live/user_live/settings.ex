defmodule CarlosassistWeb.UserLive.Settings do
  use CarlosassistWeb, :live_view

  on_mount {CarlosassistWeb.UserAuth, :require_sudo_mode}

  alias Carlosassist.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header class="text-center">
        Account Settings
        <:subtitle>Manage your account email address and password settings</:subtitle>
      </.header>

      <div class="mb-6 p-4 bg-base-200 rounded-lg">
        <h3 class="text-lg font-semibold mb-2">Account Information</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <span class="text-sm font-medium text-gray-600">Email:</span>
            <p class="text-base">{@current_scope.user.email}</p>
          </div>
          <div>
            <span class="text-sm font-medium text-gray-600">Phone:</span>
            <p class="text-base">{@current_scope.user.phone}</p>
          </div>
          <div>
            <span class="text-sm font-medium text-gray-600">Role:</span>
            <p class="text-base capitalize">{@current_scope.user.role}</p>
          </div>
        </div>
      </div>
      
    <!-- Volunteer Information Section -->
      <div :if={@current_scope.user.role == "volunteer"} class="mb-6">
        <h3 class="text-lg font-semibold mb-4">Volunteer Information</h3>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <.form
              for={@volunteer_form}
              id="volunteer_form"
              phx-submit="update_volunteer_info"
              phx-change="validate_volunteer_info"
            >
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input
                  field={@volunteer_form[:volunteer_license_plate]}
                  type="text"
                  label="License Plate Number"
                  required
                />
                <.input
                  field={@volunteer_form[:volunteer_car]}
                  type="text"
                  label="Car Make/Model/Color"
                  required
                />

                <div class="md:col-span-2">
                  <.input
                    field={@volunteer_form[:volunteer_bio]}
                    type="textarea"
                    label="Bio / Notes"
                    placeholder="Tell riders about yourself, your experience, etc."
                  />
                </div>
              </div>
              <div class="card-actions justify-end mt-4">
                <.button variant="primary" phx-disable-with="Updating...">
                  Update Volunteer Info
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form for={@phone_form} id="phone_form" phx-submit="update_phone" phx-change="validate_phone">
        <.input
          field={@phone_form[:phone]}
          type="tel"
          label="Phone Number"
          autocomplete="tel"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Phone Number</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          autocomplete="username"
          value={@current_email}
        />
        <input
          name={@password_form[:phone].name}
          type="hidden"
          id="hidden_user_phone"
          autocomplete="phone"
          value={@current_phone}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_email: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)
    phone_changeset = Accounts.change_user_phone(user, %{})

    volunteer_changeset =
      if user.role == "volunteer" do
        Accounts.change_user_email(user, %{}, validate_email: false)
      else
        nil
      end

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:current_phone, user.phone)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:phone_form, to_form(phone_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(
        :volunteer_form,
        if(volunteer_changeset, do: to_form(volunteer_changeset), else: nil)
      )
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_email: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_volunteer_info", params, socket) do
    %{"user" => user_params} = params

    volunteer_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_email: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, volunteer_form: volunteer_form)}
  end

  def handle_event("update_volunteer_info", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        # Update the current_scope with new user data
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        {:noreply,
         socket
         |> assign(:current_scope, updated_scope)
         |> put_flash(:info, "Volunteer information updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, volunteer_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_phone", params, socket) do
    %{"user" => user_params} = params

    phone_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_phone(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, phone_form: phone_form)}
  end

  def handle_event("update_phone", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_phone(user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_phone, user.phone)
         |> put_flash(:info, "Phone number updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, phone_form: to_form(changeset))}
    end
  end
end
