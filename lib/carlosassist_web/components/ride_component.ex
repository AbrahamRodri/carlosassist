defmodule CarlosassistWeb.RideComponent do
  use CarlosassistWeb, :live_component

  alias Carlosassist.Rides
  alias Carlosassist.Rides.Ride

  def mount(_params, _session, socket) do
    changeset = Rides.change_ride(%Ride{})

    {:ok,
     socket
     |> assign(:rides, [])
     |> assign(:form, to_form(changeset))
     |> assign(:show_form, false)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Ensure all required assigns are present
    socket =
      socket
      |> assign_new(:show_form, fn -> false end)
      |> assign_new(:form, fn -> to_form(Rides.change_ride(%Ride{})) end)
      |> assign_new(:rides, fn -> [] end)

    if connected?(socket) and assigns[:current_scope] do
      rides = Rides.list_rides_for_user(assigns.current_scope)
      {:ok, assign(socket, :rides, rides)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, :show_form, true)}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    changeset = Rides.change_ride(%Ride{})

    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"ride" => ride_params}, socket) do
    changeset =
      %Ride{}
      |> Rides.change_ride(ride_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"ride" => ride_params}, socket) do
    case Rides.create_ride(ride_params, socket.assigns.current_scope) do
      {:ok, ride} ->
        rides = [ride | socket.assigns.rides]
        changeset = Rides.change_ride(%Ride{})

        {:noreply,
         socket
         |> put_flash(:info, "Ride posted successfully!")
         |> assign(:rides, rides)
         |> assign(:form, to_form(changeset))
         |> assign(:show_form, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ride = Rides.get_ride!(id)

    case Rides.delete_ride(ride) do
      {:ok, _ride} ->
        rides = Enum.filter(socket.assigns.rides, &(&1.id != String.to_integer(id)))

        {:noreply,
         socket
         |> put_flash(:info, "Ride deleted successfully!")
         |> assign(:rides, rides)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete ride.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">My Rides</h1>
        <button :if={!@show_form} phx-click="show_form" phx-target={@myself} class="btn btn-primary">
          Post New Ride
        </button>
      </div>
      
    <!-- New Ride Form -->
      <div :if={@show_form} class="card bg-base-100 shadow-xl mb-8">
        <div class="card-body">
          <div class="flex justify-between items-center mb-4">
            <h2 class="card-title">Post a New Ride</h2>
            <button phx-click="hide_form" phx-target={@myself} class="btn btn-sm btn-ghost">
              ✕
            </button>
          </div>

          <.form for={@form} phx-submit="save" phx-change="validate" phx-target={@myself}>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:pickup_location]}
                type="text"
                label="Pickup Location"
                placeholder="Where should they pick you up?"
                required
              />
              <.input
                field={@form[:destination]}
                type="text"
                label="Destination"
                placeholder="Where are you going?"
                required
              />
            </div>

            <.input
              field={@form[:description]}
              type="textarea"
              label="Description"
              placeholder="Add any additional details about your ride request..."
              required
            />

            <.input
              field={@form[:ride_date]}
              type="datetime-local"
              label="When do you need the ride?"
              required
            />

            <div class="card-actions justify-end mt-4">
              <button type="button" phx-click="hide_form" phx-target={@myself} class="btn btn-ghost">
                Cancel
              </button>
              <button type="submit" class="btn btn-primary">
                Post Ride
              </button>
            </div>
          </.form>
        </div>
      </div>
      
    <!-- Rides List -->
      <div :if={@rides == []} class="text-center py-12">
        <div class="text-6xl mb-4">🚗</div>
        <h3 class="text-xl font-semibold mb-2">No rides posted yet</h3>
        <p class="text-base-content/60 mb-4">
          Post your first ride request to get started!
        </p>
        <button :if={!@show_form} phx-click="show_form" phx-target={@myself} class="btn btn-primary">
          Post Your First Ride
        </button>
      </div>

      <div class="grid gap-4">
        <div
          :for={ride <- @rides}
          class="card bg-base-100 shadow-lg hover:shadow-xl transition-shadow"
        >
          <div class="card-body">
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <h3 class="card-title text-lg">
                  {ride.pickup_location} → {ride.destination}
                </h3>
                <div class="flex items-center gap-4 text-sm text-base-content/60 mt-2">
                  <span class="flex items-center gap-1">
                    📅 {Calendar.strftime(ride.ride_date, "%B %d, %Y at %I:%M %p")}
                  </span>
                  <span class={"badge " <> status_badge_class(ride.status)}>
                    {String.capitalize(ride.status)}
                  </span>
                </div>
                <p class="mt-3 text-base-content/80">{ride.description}</p>
              </div>

              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
                  ⋮
                </div>
                <ul
                  tabindex="0"
                  class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52"
                >
                  <li>
                    <button
                      phx-click="delete"
                      phx-target={@myself}
                      phx-value-id={ride.id}
                      data-confirm="Are you sure you want to delete this ride?"
                      class="text-error"
                    >
                      Delete Ride
                    </button>
                  </li>
                </ul>
              </div>
            </div>

            <div class="card-actions justify-end mt-4">
              <div class="text-xs text-base-content/40">
                Posted {time_ago(ride.inserted_at)}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("confirmed"), do: "badge-success"
  defp status_badge_class("completed"), do: "badge-success"
  defp status_badge_class("cancelled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-neutral"

  defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end
end
