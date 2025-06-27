defmodule CarlosassistWeb.VolunteerDashboardLive do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Rides

  # Helper function to get rides available for a volunteer (excluding rides they've already requested)
  defp get_available_rides_for_volunteer(volunteer_user_id) do
    all_pending_rides = Rides.list_pending_rides_for_volunteers()

    requested_ride_ids =
      Rides.list_volunteer_requests_for_user(volunteer_user_id)
      |> Enum.map(& &1.ride_id)
      |> MapSet.new()

    Enum.filter(all_pending_rides, fn ride ->
      not MapSet.member?(requested_ride_ids, ride.id)
    end)
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to ride updates
      Phoenix.PubSub.subscribe(Carlosassist.PubSub, "rides")
    end

    current_user = socket.assigns.current_scope.user
    my_requests = Rides.list_volunteer_requests_for_user(current_user.id)
    available_rides = get_available_rides_for_volunteer(current_user.id)

    {:ok,
     socket
     |> assign(:pending_rides, available_rides)
     |> assign(:my_requests, my_requests)
     |> assign(:show_request_modal, false)
     |> assign(:selected_ride, nil)
     |> assign(:request_message, "")}
  end

  def handle_event("request_ride", %{"ride_id" => ride_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_request_modal, true)
     |> assign(:selected_ride, String.to_integer(ride_id))
     |> assign(:request_message, "")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_request_modal, false)
     |> assign(:selected_ride, nil)}
  end

  def handle_event("submit_request", %{"message" => message}, socket) do
    current_user = socket.assigns.current_scope.user

    case Rides.create_volunteer_request(%{
           ride_id: socket.assigns.selected_ride,
           volunteer_user_id: current_user.id,
           message: message
         }) do
      {:ok, request} ->
        # Broadcast to riders that a new volunteer request was created
        Phoenix.PubSub.broadcast(
          Carlosassist.PubSub,
          "ride:#{socket.assigns.selected_ride}",
          {:new_volunteer_request, request}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Your request has been sent to the rider!")
         |> assign(:show_request_modal, false)
         |> assign(:selected_ride, nil)
         |> assign(:my_requests, Rides.list_volunteer_requests_for_user(current_user.id))
         |> assign(:pending_rides, get_available_rides_for_volunteer(current_user.id))}

      {:error, changeset} ->
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Error: #{error_message}")}
    end
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :request_message, message)}
  end

  def handle_info({:volunteer_request_updated}, socket) do
    # Refresh volunteer requests when there's an update
    current_user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(:pending_rides, get_available_rides_for_volunteer(current_user.id))
     |> assign(:my_requests, Rides.list_volunteer_requests_for_user(current_user.id))}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <.header>
        Volunteer Dashboard
        <:subtitle>View and request to help with rides</:subtitle>
      </.header>
      
    <!-- My Requests Section -->
      <div class="mt-8">
        <h2 class="text-xl font-semibold mb-4">My Requests</h2>
        <div :if={@my_requests == []} class="text-base-content/60 italic">
          You haven't requested any rides yet.
        </div>
        <div :if={@my_requests != []} class="grid gap-4">
          <div :for={request <- @my_requests} class="card bg-base-100 p-4 rounded-lg shadow">
            <div class="flex justify-between items-start">
              <div>
                <h3 class="font-medium">Ride Request</h3>
                <p class="text-sm text-base-content/60">
                  From: {request.ride.pickup_location} to {request.ride.destination}
                </p>
                <p class="text-sm text-base-content/60">
                  Date: {Calendar.strftime(request.ride.ride_date, "%B %d, %Y at %I:%M %p")}
                </p>
              </div>
              <div class={[
                "badge text-xs font-medium",
                request.status == "pending" && "badge-warning",
                request.status == "accepted" && "badge-success",
                request.status == "rejected" && "badge-error"
              ]}>
                {String.capitalize(request.status)}
              </div>
            </div>
            <p :if={request.message} class="text-sm text-base-content/80 mt-2">
              <strong>Your message:</strong> {request.message}
            </p>
            <div
              :if={request.status == "accepted"}
              class="mt-3 p-3 bg-success/10 border border-success/20 rounded"
            >
              <p class="text-sm font-medium text-success">🎉 Great news! Your help was accepted!</p>
              <p class="text-xs text-success/80 mt-1">
                The rider has confirmed you as their volunteer for this ride.
              </p>
              <div class="mt-2 text-sm">
                <p class="text-base-content">
                  <strong>Rider Contact:</strong> {request.ride.user.email}
                </p>
                <p class="text-xs text-success/80 mt-1">
                  Please reach out to coordinate pickup details!
                </p>
              </div>
            </div>
            <div
              :if={request.status == "rejected"}
              class="mt-3 p-3 bg-error/10 border border-error/20 rounded"
            >
              <p class="text-sm text-error/80">
                This request was not selected, but thank you for offering to help!
              </p>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Available Rides Section -->
      <div class="mt-8">
        <h2 class="text-xl font-semibold mb-4">Available Rides</h2>
        <div :if={@pending_rides == []} class="text-base-content/60 italic">
          No rides available at the moment.
        </div>
        <div :if={@pending_rides != []} class="grid gap-6">
          <div :for={ride <- @pending_rides} class="card bg-base-100 p-6 rounded-lg shadow">
            <div class="flex justify-between items-start mb-4">
              <div class="flex-1">
                <h3 class="text-lg font-medium">Ride Request</h3>
                <p class="text-base-content/60">Rider: {ride.user.email}</p>
              </div>
              <button phx-click="request_ride" phx-value-ride_id={ride.id} class="btn btn-primary">
                Request to Help
              </button>
            </div>

            <div class="grid md:grid-cols-2 gap-4 mb-4">
              <div>
                <p class="text-sm font-medium text-base-content/60">Pickup Location</p>
                <p class="text-base-content">{ride.pickup_location}</p>
              </div>
              <div>
                <p class="text-sm font-medium text-base-content/60">Destination</p>
                <p class="text-base-content">{ride.destination}</p>
              </div>
            </div>

            <div class="mb-4">
              <p class="text-sm font-medium text-base-content/60">Date & Time</p>
              <p class="text-base-content">
                {Calendar.strftime(ride.ride_date, "%B %d, %Y at %I:%M %p")}
              </p>
            </div>

            <div class="mb-4">
              <p class="text-sm font-medium text-base-content/60">Description</p>
              <p class="text-base-content">{ride.description}</p>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Request Modal -->
      <div
        :if={@show_request_modal}
        class="fixed inset-0 bg-black/50 overflow-y-auto h-full w-full z-50"
      >
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-base-100">
          <div class="mt-3">
            <h3 class="text-lg font-medium leading-6 text-base-content mb-4">
              Request to Help with Ride
            </h3>
            <div class="mt-2 px-7 py-3">
              <p class="text-sm text-base-content/60 mb-4">
                Your volunteer information will be shared with the rider along with your message.
              </p>
              <div class="mb-4">
                <label class="block text-sm font-medium text-base-content mb-2">
                  Optional Message
                </label>
                <textarea
                  id="volunteer-message"
                  phx-hook="TextareaAutosize"
                  phx-update="ignore"
                  rows="3"
                  class="textarea textarea-bordered w-full"
                  placeholder="Let the rider know why you'd like to help or any relevant information..."
                  phx-change="update_message"
                  value={@request_message}
                ></textarea>
              </div>
            </div>
            <div class="flex justify-end space-x-3">
              <button phx-click="close_modal" class="btn btn-ghost">
                Cancel
              </button>
              <button
                phx-click="submit_request"
                phx-value-message={@request_message}
                class="btn btn-primary"
              >
                Send Request
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
