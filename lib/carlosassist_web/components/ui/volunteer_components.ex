defmodule CarlosassistWeb.UI.VolunteerComponents do
  use Phoenix.Component
  import CarlosassistWeb.CoreComponents
  import CarlosassistWeb.UI.MapComponents
  use CarlosassistWeb, :verified_routes

  @doc """
  Renders the volunteer requests section showing all requests made by the volunteer.
  """
  attr :requests, :list, required: true

  def volunteer_requests_section(assigns) do
    ~H"""
    <div :if={@requests == []} class="text-base-content/60 italic">
      You haven't requested any rides yet.
    </div>
    <div :if={@requests != []} class="grid gap-4">
      <.volunteer_request_card :for={request <- @requests} request={request} />
    </div>
    """
  end

  @doc """
  Renders a single volunteer request card.
  """
  attr :request, :map, required: true

  def volunteer_request_card(assigns) do
    ~H"""
    <div class="card bg-base-100 p-4 rounded-lg shadow">
      <div class="flex justify-between items-start">
        <div class="flex items-start gap-4 flex-1">
          <.avatar src={@request.ride.user.profile_pic_location} alt="Rider Profile" size="md" />
          <div class="flex-1">
            <h3 class="font-medium">Ride Request</h3>
            <p class="text-sm text-base-content/60">
              From: {@request.ride.pickup_name} to {@request.ride.destination_name}
            </p>
            <p class="text-sm text-base-content/60">
              Date: {Calendar.strftime(@request.ride.ride_date, "%B %d, %Y at %I:%M %p")}
            </p>
          </div>
        </div>
        <.request_status_badge status={@request.status} />
      </div>
      <p :if={@request.message} class="text-sm text-base-content/80 mt-2">
        <strong>Your message:</strong> {@request.message}
      </p>
      <.accepted_request_info :if={@request.status == "accepted"} request={@request} />
      <.rejected_request_info :if={@request.status == "rejected"} />
    </div>
    """
  end

  @doc """
  Renders the available rides section for volunteers to browse.
  """
  attr :rides, :list, required: true

  def available_rides_section(assigns) do
    ~H"""
    <div :if={@rides == []} class="text-base-content/60 italic">
      No rides available at the moment.
    </div>
    <div :if={@rides != []} class="grid gap-6">
      <.available_ride_card :for={ride <- @rides} ride={ride} />
    </div>
    """
  end

  @doc """
  Renders a single available ride card.
  """
  attr :ride, :map, required: true

  def available_ride_card(assigns) do
    ~H"""
    <div class="card bg-base-100 p-6 rounded-lg shadow">
      <div class="flex justify-between items-start mb-4">
        <div class="flex items-start gap-4 flex-1">
          <.avatar src={@ride.user.profile_pic_location} alt="Rider Profile" size="lg" />
          <div class="flex-1">
            <h3 class="text-lg font-medium">Ride Request</h3>
            <p class="text-base-content/60">{@ride.user.email}</p>
            <p class="text-sm text-base-content/60">{@ride.user.phone}</p>
          </div>
        </div>
        <button phx-click="request_ride" phx-value-ride_id={@ride.id} class="btn btn-primary">
          Request to Help
        </button>
      </div>

      <.ride_details ride={@ride} />
    </div>
    """
  end

  @doc """
  Renders the volunteer request modal.
  """
  attr :selected_ride, :integer, required: true
  attr :request_message, :string, required: true
  attr :rides, :list, required: true

  def volunteer_request_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/50 overflow-y-auto h-full w-full z-50"
      phx-key="Escape"
      phx-window-keydown="close_modal"
    >
      <div
        class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-base-100"
        phx-click-away="close_modal"
      >
        <div class="mt-3">
          <h3 class="text-lg font-medium leading-6 text-base-content mb-4">
            Request to Help with Ride
          </h3>
          <.selected_ride_info selected_ride={@selected_ride} rides={@rides} />
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
    """
  end

  # Private helper components

  defp request_status_badge(assigns) do
    ~H"""
    <div class={[
      "badge text-xs font-medium",
      @status == "pending" && "badge-warning",
      @status == "accepted" && "badge-success",
      @status == "rejected" && "badge-error"
    ]}>
      {String.capitalize(@status)}
    </div>
    """
  end

  defp accepted_request_info(assigns) do
    ~H"""
    <div class="mt-3 p-3 bg-success/10 border border-success/20 rounded">
      <p class="text-sm font-medium text-success">🎉 Great news! Your help was accepted!</p>
      <p class="text-xs text-success/80 mt-1">
        The rider has confirmed you as their volunteer for this ride.
      </p>
      <div class="mt-3 space-y-2">
        <h4 class="text-sm font-semibold text-base-content">Rider Contact Information</h4>
        <div class="grid grid-cols-2 gap-2 text-sm">
          <div>
            <span class="text-base-content/60">Email:</span>
            <div class="font-medium">{@request.ride.user.email}</div>
          </div>
          <div>
            <span class="text-base-content/60">Phone:</span>
            <div class="font-medium">{@request.ride.user.phone}</div>
          </div>
        </div>
        
        <!-- Exact Location Details (Only Shown After Acceptance) -->
        <div class="mt-4 p-3 bg-success/5 border border-success/10 rounded">
          <h4 class="text-sm font-semibold text-success mb-2">📍 Exact Locations (Now Available)</h4>
          <div class="grid grid-cols-1 gap-3 text-sm mb-4">
            <div>
              <span class="text-base-content/60 font-medium">Pickup:</span>
              <div class="font-medium">{@request.ride.pickup_address || @request.ride.pickup_name}</div>
            </div>
            <div>
              <span class="text-base-content/60 font-medium">Destination:</span>
              <div class="font-medium">{@request.ride.destination_address || @request.ride.destination_name}</div>
            </div>
          </div>
          <!-- Exact Location Map -->
          <div class="mt-3">
            <.exact_location_map ride={@request.ride} class="h-48" />
          </div>
        </div>
        <div class="mt-3 flex gap-2">
          <.link navigate={~p"/dashboard/inbox"} class="btn btn-primary btn-sm">
            💬 Chat with Rider
          </.link>
        </div>
        <p class="text-xs text-success/80 mt-2">
          Use the chat to coordinate pickup details and communicate securely!
        </p>
      </div>
    </div>
    """
  end

  defp rejected_request_info(assigns) do
    ~H"""
    <div class="mt-3 p-3 bg-error/10 border border-error/20 rounded">
      <p class="text-sm text-error/80">
        This request was not selected, but thank you for offering to help!
      </p>
    </div>
    """
  end

  defp ride_details(assigns) do
    ~H"""
    <!-- Privacy Notice for Volunteers -->
    <div class="bg-info/10 border border-info/20 p-3 rounded-lg mb-4">
      <p class="text-sm text-info flex items-center gap-2">
        <span class="text-lg">🔒</span>
        <strong>Privacy Protected:</strong> Exact addresses will be shared only after the rider accepts your volunteer request.
      </p>
    </div>

    <div class="grid md:grid-cols-2 gap-4 mb-4">
      <div>
        <p class="text-sm font-medium text-base-content/60">Pickup Location</p>
        <p class="text-base-content font-medium">{@ride.pickup_name}</p>
        <p class="text-xs text-base-content/50">General Area (3-mile radius)</p>
      </div>
      <div>
        <p class="text-sm font-medium text-base-content/60">Destination</p>
        <p class="text-base-content font-medium">{@ride.destination_name}</p>
        <p class="text-xs text-base-content/50">General Area (3-mile radius)</p>
      </div>
    </div>

    <div class="mb-4">
      <p class="text-sm font-medium text-base-content/60">Date & Time</p>
      <p class="text-base-content">
        {Calendar.strftime(@ride.ride_date, "%B %d, %Y at %I:%M %p")}
      </p>
    </div>

    <div class="mb-4">
      <p class="text-sm font-medium text-base-content/60">Description</p>
      <p class="text-base-content">{@ride.description}</p>
    </div>

    <!-- Privacy Radius Map Preview -->
    <div class="mb-4">
      <p class="text-sm font-medium text-base-content/60 mb-2">Area Preview</p>
      <.privacy_radius_map ride={@ride} location_type={:pickup} class="h-32" />
    </div>
    """
  end

  defp selected_ride_info(assigns) do
    ~H"""
    <div class="mb-4">
      <% selected_ride = Enum.find(@rides, fn ride -> ride.id == @selected_ride end) %>
      <div :if={selected_ride} class="bg-base-200 p-4 rounded-lg">
        <p class="font-medium">
          {selected_ride.pickup_name} → {selected_ride.destination_name}
        </p>
        <p class="text-sm text-base-content/60">
          {Calendar.strftime(selected_ride.ride_date, "%B %d, %Y at %I:%M %p")}
        </p>
      </div>
    </div>
    """
  end
end
