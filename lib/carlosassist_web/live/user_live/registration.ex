defmodule CarlosassistWeb.UserLive.Registration do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts
  alias Carlosassist.Accounts.User
  import CarlosassistWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} width="narrow">
      <div class="sheet">
        <.header kicker="Register">
          Create your account
          <:subtitle>
            Already have an account?
            <.link navigate={~p"/users/log-in"} class="link link-inline">Log in</.link>
          </:subtitle>
        </.header>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:role]}
            type="select"
            label="What would you like to do?"
            options={[{"I need a ride", "rider"}, {"I want to drive", "volunteer"}]}
          />

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.input field={@form[:phone]} type="text" label="Phone number" autocomplete="tel" required />

          <div class="field">
            <label for={@uploads.profile_pic.ref} class="field-label">
              Your photo (you can add it later)
            </label>
            <.live_file_input upload={@uploads.profile_pic} class="field-file" />
            <p class="field-help">
              A photo helps the other person know who to look for. JPG or PNG.
            </p>

            <%= for entry <- @uploads.profile_pic.entries do %>
              <div :if={entry.progress > 0} class="upload-progress">
                <span style={"width: #{entry.progress}%"}></span>
              </div>

              <p :for={err <- upload_errors(@uploads.profile_pic, entry)} class="field-error">
                <.icon name="hero-exclamation-circle" class="size-6 shrink-0" />
                {upload_error_text(err)}
              </p>
            <% end %>
          </div>

          <div :if={@selected_role == "volunteer"} class="inset mb-6">
            <h2 class="card-title mb-1">About you and your car</h2>
            <p class="muted small mb-4">Riders see this when you offer to drive them.</p>
            <.input
              field={@form[:volunteer_license_plate]}
              type="text"
              label="License plate number"
              required
            />
            <.input
              field={@form[:volunteer_car]}
              type="text"
              label="Car make, model and color"
              placeholder="Red Toyota Camry 2018"
              required
            />

            <.input
              field={@form[:volunteer_bio]}
              type="textarea"
              label="A few words about you (you can leave this empty)"
              placeholder="Anything you would like riders to know about you."
            />
          </div>

          <.button variant="primary" phx-disable-with="Creating account..." class="btn-block">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp upload_error_text(:too_large), do: "This photo is too large. The limit is 10 MB."
  defp upload_error_text(:not_accepted), do: "Please choose a JPG or PNG photo."
  defp upload_error_text(:too_many_files), do: "Please choose one photo only."
  defp upload_error_text(_), do: "This photo could not be uploaded."

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: CarlosassistWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(params, _session, socket) do
    # The home page links here with ?role=rider or ?role=volunteer.
    role = if params["role"] in ["rider", "volunteer"], do: params["role"], else: "rider"
    changeset = %User{} |> User.registration_changeset(%{"role" => role})

    {:ok,
     socket
     |> assign_form(changeset)
     |> allow_upload(
       :profile_pic,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign(:selected_role, role), temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    profile_pic_location =
      case consume_uploaded_entries(socket, :profile_pic, fn meta, entry ->
             {:ok,
              Carlosassist.Uploads.store_profile_pic!(meta.path, entry.uuid, entry.client_name)}
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
