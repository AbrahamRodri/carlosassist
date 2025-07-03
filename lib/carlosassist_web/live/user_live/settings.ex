defmodule CarlosassistWeb.UserLive.Settings do
  use CarlosassistWeb, :live_view

  on_mount {CarlosassistWeb.UserAuth, :require_sudo_mode}

  alias Carlosassist.Accounts

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
    profile_pic_changeset = Accounts.change_user_profile_pic(user, %{})

    volunteer_changeset =
      if user.role == "volunteer" do
        Accounts.change_user_volunteer_info(user, %{})
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
      |> assign(:profile_pic_form, to_form(profile_pic_changeset))
      |> assign(
        :volunteer_form,
        if(volunteer_changeset, do: to_form(volunteer_changeset), else: nil)
      )
      |> allow_upload(
        :profile_pic,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 10_000_000
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
      |> Accounts.change_user_volunteer_info(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, volunteer_form: volunteer_form)}
  end

  def handle_event("update_volunteer_info", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_volunteer_info(user, user_params) do
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

  def handle_event("validate_profile_pic", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_profile_pic", params, socket) do
    profile_pic_location =
      case consume_uploaded_entries(socket, :profile_pic, fn meta, entry ->
             dest =
               Path.join([
                 "priv",
                 "static",
                 "uploads",
                 "profile_pics",
                 "#{entry.uuid}-#{entry.client_name}"
               ])

             File.cp!(meta.path, dest)
             url_path = static_path(socket, "/uploads/profile_pics/#{Path.basename(dest)}")

             {:ok, url_path}
           end) do
        # Take the first (and only) uploaded file
        [path] -> path
        # No file uploaded
        [] -> nil
      end

    user = socket.assigns.current_scope.user
    user_params = Map.put(params, "profile_pic_location", profile_pic_location)

    Accounts.update_user_profile_pic(user, user_params)

    {:noreply, socket}
  end
end
