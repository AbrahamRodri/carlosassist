defmodule CarlosassistWeb.UserLive.Registration do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Accounts
  alias Carlosassist.Accounts.User
  import CarlosassistWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg">
        <div class="text-center mb-8">
          <h1 class="text-3xl sm:text-4xl text-base-content mb-2">Join CarlosAssist</h1>
          <span class="gold-rule mx-auto my-4"></span>
          <p class="text-lg text-base-content/75">
            Already a member?
            <.link navigate={~p"/users/log-in"} class="link font-bold text-primary">
              Sign in here
            </.link>
          </p>
        </div>

        <div class="parish-card p-6 sm:p-8">
          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
            <!-- Role: two big tappable cards, never a dropdown -->
            <fieldset class="mb-6">
              <legend class="text-lg font-bold text-base-content mb-3">
                How would you like to take part?
              </legend>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <label class={[
                  "cursor-pointer rounded-xl border-2 p-4 text-center transition-colors",
                  (@selected_role == "rider" && "border-primary bg-primary/10") ||
                    "border-base-300 bg-base-100 hover:border-primary/50"
                ]}>
                  <input
                    type="radio"
                    name="user[role]"
                    value="rider"
                    checked={@selected_role == "rider"}
                    class="sr-only"
                  />
                  <.icon name="hero-user" class="w-8 h-8 mx-auto mb-2 text-primary" />
                  <span class="block text-lg font-bold text-base-content">I need rides</span>
                  <span class="block text-base text-base-content/70 mt-1">
                    Neighbors will drive me
                  </span>
                </label>
                <label class={[
                  "cursor-pointer rounded-xl border-2 p-4 text-center transition-colors",
                  (@selected_role == "volunteer" && "border-primary bg-primary/10") ||
                    "border-base-300 bg-base-100 hover:border-primary/50"
                ]}>
                  <input
                    type="radio"
                    name="user[role]"
                    value="volunteer"
                    checked={@selected_role == "volunteer"}
                    class="sr-only"
                  />
                  <.icon name="hero-heart" class="w-8 h-8 mx-auto mb-2 text-primary" />
                  <span class="block text-lg font-bold text-base-content">I'd like to drive</span>
                  <span class="block text-base text-base-content/70 mt-1">
                    I'll volunteer my time
                  </span>
                </label>
              </div>
            </fieldset>

            <.input
              field={@form[:name]}
              type="text"
              label="Your name"
              placeholder="For example: Mary Johnson"
              autocomplete="name"
              required
              phx-mounted={JS.focus()}
            />

            <.input
              field={@form[:email]}
              type="email"
              label="Email address"
              placeholder="you@example.com"
              autocomplete="username"
              required
            />

            <.input
              field={@form[:phone]}
              type="tel"
              label="Phone number"
              placeholder="For example: 555-123-4567"
              autocomplete="tel"
              required
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Choose a password"
              placeholder="At least 12 characters"
              autocomplete="new-password"
            />
            <p class="text-base text-base-content/70 -mt-1 mb-3">
              You'll use this to sign in. If you'd rather not have a password,
              leave it blank — you can always sign in with an emailed link.
            </p>

            <div class="mt-2 mb-4">
              <span class="block text-base font-bold text-base-content mb-1">
                A photo of yourself <span class="font-normal text-base-content/60">(optional)</span>
              </span>
              <p class="text-base text-base-content/70 mb-2">
                A friendly photo helps neighbors recognize you.
              </p>
              <.live_file_input
                upload={@uploads.profile_pic}
                class="file-input file-input-bordered w-full"
              />

              <%= for entry <- @uploads.profile_pic.entries do %>
                <div class="mt-2">
                  <progress
                    :if={entry.progress > 0}
                    class="progress progress-primary w-full"
                    value={entry.progress}
                    max="100"
                  >
                  </progress>

                  <%= for err <- upload_errors(@uploads.profile_pic, entry) do %>
                    <p class="mt-1 text-base font-semibold text-error">{friendly_upload_error(err)}</p>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div
              :if={@selected_role == "volunteer"}
              class="space-y-1 mt-6 mb-4 p-4 bg-base-200 rounded-xl border-2 border-base-300"
            >
              <h3 class="text-lg font-bold text-base-content mb-2">About your car</h3>
              <p class="text-base text-base-content/70 mb-3">
                Riders see this so they know what car to look for.
              </p>
              <.input
                field={@form[:volunteer_car]}
                type="text"
                label="Car color, make, and model"
                placeholder="For example: Red Toyota Camry"
                required
              />
              <.input
                field={@form[:volunteer_license_plate]}
                type="text"
                label="License plate"
                required
              />
              <.input
                field={@form[:volunteer_bio]}
                type="textarea"
                label="A little about you (optional)"
                placeholder="For example: Retired teacher, parishioner for 20 years. Happy to help with walkers and groceries."
              />
            </div>

            <.button
              variant="primary"
              phx-disable-with="Creating your account..."
              class="w-full btn-lg mt-4"
            >
              Create my account
            </.button>
            <p class="text-center text-base text-base-content/70 mt-4">
              We'll email you a link to finish signing up. No password needed.
            </p>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: CarlosassistWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(params, _session, socket) do
    selected_role = if params["role"] in ["rider", "volunteer"], do: params["role"], else: "rider"
    changeset = %User{} |> User.registration_changeset(%{"role" => selected_role})

    {:ok,
     socket
     |> assign_form(changeset)
     |> allow_upload(
       :profile_pic,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign(:selected_role, selected_role), temporary_assigns: [form: nil]}
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
           "Welcome, #{User.first_name(user)}! We sent an email to #{user.email}. Open it and press the link inside to finish signing up."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user(%User{}, user_params)
    selected_role = Map.get(user_params, "role", socket.assigns.selected_role)

    {:noreply,
     socket
     |> assign_form(Map.put(changeset, :action, :validate))
     |> assign(:selected_role, selected_role)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp friendly_upload_error(:too_large), do: "That photo is too large. Please choose one under 10 MB."
  defp friendly_upload_error(:not_accepted), do: "Please choose a JPG or PNG photo."
  defp friendly_upload_error(:too_many_files), do: "Please choose just one photo."
  defp friendly_upload_error(other), do: to_string(other)
end
