defmodule CarlosassistWeb.UserLive.Registration do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts
  alias Carlosassist.Accounts.User
  import CarlosassistWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <.header class="text-center">
          Register for an account
          <:subtitle>
            Already registered?
            <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
              Log in
            </.link>
            to your account now.
          </:subtitle>
        </.header>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:phone]}
            type="text"
            label="Phone Number"
            autocomplete="phone"
            required
          />

          <.input field={@form[:role]} type="select" label="Role" options={["rider", "volunteer"]} />

          <div class="mt-4">
            <.live_file_input upload={@uploads.profile_pic} class="mt-1" />

            <%= for entry <- @uploads.profile_pic.entries do %>
              <div class="mt-2">
                <%= if entry.progress > 0 do %>
                  <div class="progress-bar">
                    <span style={"width: #{entry.progress}%"}>
                      {entry.progress}%
                    </span>
                  </div>
                <% end %>

                <%= for err <- upload_errors(@uploads.profile_pic, entry) do %>
                  <div class="alert alert-danger">{err}</div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div :if={@selected_role == "volunteer"} class="space-y-4 mt-4 p-4 bg-base-100 rounded-lg">
            <h3 class="text-lg font-medium text-base-content">Volunteer Information</h3>
            <.input
              field={@form[:volunteer_license_plate]}
              type="text"
              label="License Plate Number"
              required
            />
            <.input
              field={@form[:volunteer_car]}
              type="text"
              label="Car Make/Model/Color"
              placeholder="e.g., Red Toyota Camry 2018"
              required
            />

            <.input
              field={@form[:volunteer_bio]}
              type="textarea"
              label="Bio / Notes (Optional)"
              placeholder="Tell riders a bit about yourself, your experience, or anything else you'd like them to know..."
            />
          </div>

          <.button variant="primary" phx-disable-with="Creating account..." class="w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: CarlosassistWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = %User{} |> User.registration_changeset(%{})

    {:ok,
     socket
     |> assign_form(changeset)
     |> allow_upload(
       :profile_pic,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign(:selected_role, "rider"), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
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

    user_params = Map.put(user_params, "profile_pic_location", profile_pic_location)

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user(%User{}, user_params)
    selected_role = Map.get(user_params, "role", "rider")

    {:noreply,
     socket
     |> assign_form(Map.put(changeset, :action, :validate))
     |> assign(:selected_role, selected_role)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
