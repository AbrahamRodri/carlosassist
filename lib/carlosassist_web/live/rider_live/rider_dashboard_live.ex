defmodule CarlosassistWeb.RiderDashboardLive do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Rides
  alias Carlosassist.Rides.Ride

  def mount(_params, _session, socket) do
    changeset = Rides.change_ride(%Ride{})

    {:ok,
     socket
     |> assign(:current_scope, socket.assigns.current_scope)
     |> assign(:rides, [])
     |> assign(:form, to_form(changeset))
     |> assign(:show_form, false)
     |> load_rides()}
  end

  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, :show_form, true)}
  end

  def handle_event("hide_form", _params, socket) do
    changeset = Rides.change_ride(%Ride{})

    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate", %{"ride" => ride_params}, socket) do
    changeset =
      %Ride{}
      |> Rides.change_ride(ride_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("update_coordinates", %{"type" => type, "address" => address, "lat" => lat, "lng" => lng}, socket) do
    current_params = socket.assigns.form.params || %{}
    
    updated_params = case type do
      "pickup" ->
        Map.merge(current_params, %{
          "pickup_address" => address,
          "pickup_lat" => lat,
          "pickup_long" => lng
        })
      "destination" ->
        Map.merge(current_params, %{
          "destination_address" => address,
          "destination_lat" => lat,
          "destination_long" => lng
        })
    end
    
    changeset =
      %Ride{}
      |> Rides.change_ride(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("clear_coordinates", %{"type" => type}, socket) do
    current_params = socket.assigns.form.params || %{}
    
    updated_params = case type do
      "pickup" ->
        Map.merge(current_params, %{
          "pickup_address" => "",
          "pickup_lat" => nil,
          "pickup_long" => nil
        })
      "destination" ->
        Map.merge(current_params, %{
          "destination_address" => "",
          "destination_lat" => nil,
          "destination_long" => nil
        })
    end
    
    changeset =
      %Ride{}
      |> Rides.change_ride(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

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

  def handle_event(
        "accept_volunteer",
        %{"request_id" => request_id, "ride_id" => ride_id},
        socket
      ) do
    case Rides.accept_volunteer_request(String.to_integer(request_id), String.to_integer(ride_id)) do
      {:ok, {_accepted_request, _updated_ride}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Volunteer accepted! Your ride is now confirmed.")
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not accept volunteer request.")}
    end
  end

  def handle_event("reject_volunteer", %{"request_id" => request_id}, socket) do
    case Rides.reject_volunteer_request(String.to_integer(request_id)) do
      {:ok, _rejected_request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Volunteer request rejected.")
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reject volunteer request.")}
    end
  end

  # The render function is now handled by the corresponding .html.heex template

  # Private helper functions
  defp load_rides(socket) do
    rides = Rides.list_rides_for_user(socket.assigns.current_scope)
    # Get volunteer requests for each ride
    rides_with_requests =
      Enum.map(rides, fn ride ->
        volunteer_requests = Rides.list_volunteer_requests_for_ride(ride.id)
        Map.put(ride, :volunteer_requests, volunteer_requests)
      end)

    assign(socket, :rides, rides_with_requests)
  end

  # Private UI component functions
  defp new_ride_form(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl mb-8">
      <div class="card-body">
        <div class="flex justify-between items-center mb-4">
          <h2 class="card-title">Post a New Ride</h2>
          <button phx-click="hide_form" class="btn btn-sm btn-ghost">
            ✕
          </button>
        </div>

        <.form for={@form} phx-submit="save" phx-change="validate">
          <!-- Pickup Location Section -->
          <div class="mb-6">
            <h3 class="text-lg font-semibold mb-4 text-primary">📍 Pickup Location</h3>
            <div class="bg-base-200/50 p-4 rounded-lg space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input
                  field={@form[:pickup_name]}
                  type="text"
                  label="Nickname (What volunteers will see)"
                  placeholder="e.g., Home, Work, Doctor's Office"
                  required
                />
                <.input
                  field={@form[:pickup_address]}
                  type="text"
                  label="Actual Address (Private)"
                  placeholder="123 Main Street, City, State"
                  class="location-search"
                  phx-hook="LocationSearch"
                  data-location-type="pickup"
                />
              </div>
              <div class="text-sm text-base-content/60">
                <p class="flex items-center gap-2">
                  <span class="text-success">🔒</span>
                  Your exact address will only be shared with the volunteer after they're accepted
                </p>
              </div>
            </div>
          </div>

          <!-- Destination Section -->
          <div class="mb-6">
            <h3 class="text-lg font-semibold mb-4 text-primary">🎯 Destination</h3>
            <div class="bg-base-200/50 p-4 rounded-lg space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input
                  field={@form[:destination_name]}
                  type="text"
                  label="Nickname (What volunteers will see)"
                  placeholder="e.g., Hospital, Grocery Store, Appointment"
                  required
                />
                <.input
                  field={@form[:destination_address]}
                  type="text"
                  label="Actual Address (Private)"
                  placeholder="456 Oak Avenue, City, State"
                  class="location-search"
                  phx-hook="LocationSearch"
                  data-location-type="destination"
                />
              </div>
              <div class="text-sm text-base-content/60">
                <p class="flex items-center gap-2">
                  <span class="text-success">🔒</span>
                  Your exact address will only be shared with the volunteer after they're accepted
                </p>
              </div>
            </div>
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
            <button type="button" phx-click="hide_form" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Post Ride
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp rides_list(assigns) do
    ~H"""
    <div :if={@rides == []} class="text-center py-12">
      <div class="text-6xl mb-4">🚗</div>
      <h3 class="text-xl font-semibold mb-2">No rides posted yet</h3>
      <p class="text-base-content/60 mb-4">
        Post your first ride request to get started!
      </p>
      <button phx-click="show_form" class="btn btn-primary">
        Post Your First Ride
      </button>
    </div>
    <div :if={@rides != []} class="grid gap-4">
      <.ride_card :for={ride <- @rides} ride={ride} />
    </div>
    """
  end

  defp ride_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-lg hover:shadow-xl transition-shadow">
      <div class="card-body">
        <div class="flex justify-between items-start">
          <div class="flex-1">
            <h3 class="card-title text-lg">
              {@ride.pickup_name} → {@ride.destination_name}
            </h3>
            <div class="flex items-center gap-4 text-sm text-base-content/60 mt-2">
              <span class="flex items-center gap-1">
                📅 {Calendar.strftime(@ride.ride_date, "%B %d, %Y at %I:%M %p")}
              </span>
              <span class={"badge " <> status_badge_class(@ride.status)}>
                {String.capitalize(@ride.status)}
              </span>
            </div>
            <p class="mt-3 text-base-content/80">{@ride.description}</p>
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
                  phx-value-id={@ride.id}
                  data-confirm="Are you sure you want to delete this ride?"
                  class="text-error"
                >
                  Delete Ride
                </button>
              </li>
            </ul>
          </div>
        </div>
        
    <!-- Assigned Volunteer Section (for confirmed rides) -->
        <div
          :if={@ride.status == "confirmed" && @ride.volunteer}
          class="mt-6 border-t border-base-300 pt-4"
        >
          <h4 class="text-md font-semibold mb-4 text-success">
            🎉 Assigned Volunteer
          </h4>
          <div class="bg-success/5 border border-success/20 p-4 rounded-lg">
            <div class="flex items-start gap-4 mb-4">
              <.avatar src={@ride.volunteer.profile_pic_location} alt="Volunteer Profile" size="lg" />
              <div class="flex-1">
                <p class="font-medium text-base-content text-lg">
                  {@ride.volunteer.email}
                </p>
                <p class="text-sm text-base-content/60">
                  {@ride.volunteer.phone}
                </p>
              </div>
            </div>
            <.volunteer_details volunteer={@ride.volunteer} />
            <div class="mt-4 flex gap-2">
              <.link navigate={~p"/dashboard/inbox"} class="btn btn-primary btn-sm">
                💬 Chat with Volunteer
              </.link>
            </div>
          </div>
        </div>
        
    <!-- Volunteer Requests Section (for pending rides) -->
        <div
          :if={
            @ride.status == "pending" && @ride.volunteer_requests &&
              length(@ride.volunteer_requests) > 0
          }
          class="mt-6 border-t border-base-300 pt-4"
        >
          <h4 class="text-md font-semibold mb-4 text-primary">
            Volunteer Requests ({length(@ride.volunteer_requests)})
          </h4>
          <div class="space-y-4">
            <.volunteer_request_card
              :for={request <- @ride.volunteer_requests}
              request={request}
              ride={@ride}
            />
          </div>
        </div>

        <div class="card-actions justify-end mt-4">
          <div class="text-xs text-base-content/40">
            Posted {time_ago(@ride.inserted_at)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_request_card(assigns) do
    ~H"""
    <div class="bg-primary/5 border border-primary/10 p-4 rounded-lg">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div class="flex items-start gap-4 mb-4">
            <.avatar
              src={@request.volunteer_user.profile_pic_location}
              alt="Volunteer Profile"
              size="lg"
            />
            <div class="flex-1">
              <p class="font-medium text-base-content text-lg">
                {@request.volunteer_user.email}
              </p>
              <p class="text-sm text-base-content/60">
                {@request.volunteer_user.phone}
              </p>
            </div>
          </div>
          <.volunteer_details volunteer={@request.volunteer_user} />
          <div :if={@request.message} class="mt-3">
            <p class="text-sm font-medium text-base-content/60">Message from Volunteer</p>
            <p class="text-sm bg-base-200 p-2 rounded border border-base-300 italic">
              "{@request.message}"
            </p>
          </div>
        </div>
        <div class="flex gap-2 ml-4">
          <button
            phx-click="accept_volunteer"
            phx-value-request_id={@request.id}
            phx-value-ride_id={@ride.id}
            class="btn btn-sm btn-success"
            data-confirm="Accept this volunteer? This will confirm your ride and reject other requests."
          >
            Accept
          </button>
          <button
            phx-click="reject_volunteer"
            phx-value-request_id={@request.id}
            class="btn btn-sm btn-error btn-outline"
          >
            Reject
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_details(assigns) do
    ~H"""
    <div class="grid md:grid-cols-2 gap-4">
      <div>
        <p class="text-sm font-medium text-base-content/60">License Plate</p>
        <p class="font-medium text-base-content">
          {@volunteer.volunteer_license_plate || "Not provided"}
        </p>
      </div>
      <div>
        <p class="text-sm font-medium text-base-content/60">Car Details</p>
        <p class="font-medium text-base-content">
          {@volunteer.volunteer_car || "Not provided"}
        </p>
      </div>
      <div :if={@volunteer.volunteer_bio} class="md:col-span-2">
        <p class="text-sm font-medium text-base-content/60">Bio</p>
        <p class="text-sm text-base-content/80">
          {@volunteer.volunteer_bio}
        </p>
      </div>
    </div>
    """
  end

  # Helper functions
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
