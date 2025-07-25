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
    <div :if={@requests == []} class="text-base-content/60 italic text-center py-8">
      You haven't requested any rides yet.
    </div>
    <div :if={@requests != []} class="grid gap-3">
      <.simplified_volunteer_request_card :for={request <- @requests} request={request} />
    </div>
    """
  end

  @doc """
  Renders a simplified volunteer request card with minimal information.
  """
  attr :request, :map, required: true

  def simplified_volunteer_request_card(assigns) do
    ~H"""
    <div class="p-3 bg-base-100 rounded-lg border hover:shadow-md transition-shadow">
      <div class="flex items-start gap-2 mb-2">
        <.avatar src={@request.ride.user.profile_pic_location} alt="Rider" size="sm" />
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between gap-2 mb-1">
            <.request_status_badge status={@request.status} />
            <div class="flex items-center gap-1">
              <button 
                :if={@request.status == "accepted" && @request.ride.conversation}
                class="btn btn-primary btn-xs"
                onclick={"window.location.href='/dashboard/chat/#{@request.ride.conversation.id}'"}
              >
                <.icon name="hero-chat-bubble-left-right" class="w-3 h-3" />
                Chat
              </button>
              
              <.icon 
                :if={@request.status == "pending"} 
                name="hero-clock" 
                class="w-4 h-4 text-warning" 
              />
              <.icon 
                :if={@request.status == "accepted"} 
                name="hero-check-circle" 
                class="w-4 h-4 text-success" 
              />
              <.icon 
                :if={@request.status == "rejected"} 
                name="hero-x-circle" 
                class="w-4 h-4 text-error" 
              />
            </div>
          </div>
          
          <div 
            class="cursor-pointer hover:bg-base-200/50 -m-1 p-1 rounded"
            phx-click="show_request_details"
            phx-value-request_id={@request.id}
          >
            <p class="font-medium text-sm leading-tight mb-1">
              {@request.ride.pickup_name}
            </p>
            <p class="font-medium text-sm leading-tight mb-2 flex items-center gap-1">
              <.icon name="hero-arrow-right" class="w-3 h-3 text-base-content/40" />
              {@request.ride.destination_name}
            </p>
            
            <div class="flex items-center justify-between">
              <p class="text-xs text-base-content/60">
                {Calendar.strftime(@request.ride.ride_date, "%b %d, %I:%M %p")}
              </p>
              <.icon name="hero-chevron-right" class="w-3 h-3 text-base-content/40" />
            </div>
          </div>
        </div>
      </div>
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
  Renders a single ride browser with Tinder-style navigation.
  """
  attr :rides, :list, required: true
  attr :current_index, :integer, required: true

  def single_ride_browser(assigns) do
    ~H"""
    <div :if={@rides == []} class="text-base-content/60 italic text-center py-12">
      No rides available at the moment.
    </div>
    <div :if={@rides != []} class="max-w-2xl mx-auto">
      <% current_ride = Enum.at(@rides, @current_index) %>
      
      <!-- Progress indicator -->
      <div class="flex justify-center items-center mb-6">
        <span class="text-sm text-base-content/60 bg-base-200 px-3 py-1 rounded-full">
          Showing <%= @current_index + 1 %> of <%= length(@rides) %> rides
        </span>
      </div>
      
      <!-- Single ride card -->
      <div class="card bg-base-100 p-6 rounded-lg shadow-lg border">
        <div class="flex justify-between items-start mb-4">
          <div class="flex items-start gap-4 flex-1">
            <.avatar src={current_ride.user.profile_pic_location} alt="Rider Profile" size="xl" />
            <div class="flex-1">
              <h3 class="text-xl font-semibold">Ride Request</h3>
              <p class="text-base-content/60">{current_ride.user.email}</p>
              <p class="text-sm text-base-content/60">{current_ride.user.phone}</p>
            </div>
          </div>
        </div>

        <.ride_details ride={current_ride} />
        
        <!-- Navigation buttons -->
        <div class="mt-6 pt-4 border-t border-base-300 space-y-3 sm:space-y-0 sm:flex sm:justify-between sm:items-center">
          <button 
            phx-click="previous_ride" 
            class="btn btn-ghost btn-sm w-full sm:w-auto"
            disabled={length(@rides) <= 1}
          >
            <.icon name="hero-chevron-left" class="w-4 h-4" />
            <span class="hidden sm:inline">Previous</span>
            <span class="sm:hidden">← Prev</span>
          </button>
          
          <div class="flex gap-2 sm:gap-3">
            <button 
              phx-click="next_ride" 
              class="btn btn-outline btn-sm flex-1 sm:flex-none"
              disabled={length(@rides) <= 1}
            >
              <.icon name="hero-chevron-right" class="w-4 h-4" />
              <span class="hidden sm:inline">Skip</span>
              <span class="sm:hidden">Skip</span>
            </button>
            <button 
              phx-click="request_ride" 
              phx-value-ride_id={current_ride.id} 
              class="btn btn-primary btn-sm flex-1 sm:flex-none"
            >
              <.icon name="hero-heart" class="w-4 h-4 sm:w-5 sm:h-5" />
              <span class="hidden sm:inline">Request to Help</span>
              <span class="sm:hidden">Request</span>
            </button>
          </div>
        </div>
      </div>
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
      <p class="text-sm font-medium text-success flex items-center gap-2">
        <.icon name="hero-check-circle" class="w-4 h-4" />
        Great news! Your help was accepted!
      </p>
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
          <h4 class="text-sm font-semibold text-success mb-2 flex items-center gap-2">
            <.icon name="hero-map-pin" class="w-4 h-4" />
            Exact Locations (Now Available)
          </h4>
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
            <.exact_location_map ride={@request.ride} class="h-64" />
          </div>
        </div>
        <div class="mt-3 flex gap-2">
          <.link 
            :if={@request.ride.conversation}
            navigate={~p"/dashboard/chat/#{@request.ride.conversation.id}"} 
            class="btn btn-primary btn-sm flex items-center gap-2"
          >
            <.icon name="hero-chat-bubble-left-right" class="w-4 h-4" />
            Chat with Rider
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
    <div class="bg-base-200 border border-base-300 p-3 rounded-lg mb-4">
      <p class="text-sm text-base-content/70 flex items-center gap-2">
        <.icon name="hero-lock-closed" class="w-4 h-4 text-base-content/50" />
        <strong>Privacy Protected:</strong> Exact addresses will be shared only after the rider accepts your volunteer request.
      </p>
    </div>

    <div class="grid md:grid-cols-2 gap-4 mb-4">
      <div>
        <p class="text-sm font-medium text-base-content/60">Pickup Location</p>
        <p class="text-base-content font-medium">{@ride.pickup_name}</p>
        <p class="text-xs text-base-content/50">General Area (0.5-mile radius)</p>
      </div>
      <div>
        <p class="text-sm font-medium text-base-content/60">Destination</p>
        <p class="text-base-content font-medium">{@ride.destination_name}</p>
        <p class="text-xs text-base-content/50">General Area (0.5-mile radius)</p>
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
      <.privacy_radius_map ride={@ride} location_type={:pickup} class="h-64" />
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

  @doc """
  Renders the request details modal for volunteer's own requests.
  """
  attr :request, :map, required: true

  def volunteer_request_details_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/50 overflow-y-auto h-full w-full z-50"
      phx-key="Escape"
      phx-window-keydown="hide_request_details"
    >
      <div
        class="relative top-8 mx-auto p-6 border w-full max-w-4xl shadow-lg rounded-lg bg-base-100 m-4"
        phx-click-away="hide_request_details"
      >
        <!-- Header -->
        <div class="flex justify-between items-start mb-6">
          <div class="flex items-center gap-3">
            <div class="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
              <.avatar src={@request.ride.user.profile_pic_location} alt="Rider Profile" size="md" />
            </div>
            <div>
              <h2 class="text-xl font-semibold text-base-content">
                My Volunteer Request
              </h2>
              <.request_status_badge status={@request.status} />
            </div>
          </div>
          <button 
            phx-click="hide_request_details" 
            class="btn btn-ghost btn-sm p-2 hover:bg-base-200 rounded-lg"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <!-- Request Status Information -->
        <div class="mb-6">
          <div :if={@request.status == "pending"} class="bg-warning/10 border border-warning/20 p-4 rounded-lg">
            <p class="text-sm text-warning flex items-center gap-2 font-medium">
              <.icon name="hero-clock" class="w-4 h-4" />
              Request Pending
            </p>
            <p class="text-xs text-warning/80 mt-1">
              Waiting for the rider to review your volunteer request.
            </p>
          </div>
          
          <div :if={@request.status == "accepted"} class="bg-success/10 border border-success/20 p-4 rounded-lg">
            <p class="text-sm text-success flex items-center gap-2 font-medium">
              <.icon name="hero-check-circle" class="w-4 h-4" />
              Request Accepted!
            </p>
            <p class="text-xs text-success/80 mt-1">
              Great! The rider has chosen you as their volunteer.
            </p>
          </div>
          
          <div :if={@request.status == "rejected"} class="bg-error/10 border border-error/20 p-4 rounded-lg">
            <p class="text-sm text-error flex items-center gap-2 font-medium">
              <.icon name="hero-x-circle" class="w-4 h-4" />
              Request Not Selected
            </p>
            <p class="text-xs text-error/80 mt-1">
              This request was not selected, but thank you for offering to help!
            </p>
          </div>
        </div>

        <!-- Ride Information -->
        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="space-y-4">
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-map-pin" class="w-4 h-4" /> Pickup Location
              </h3>
              <p class="font-semibold text-base-content">{@request.ride.pickup_name}</p>
              <p :if={@request.status == "accepted" && @request.ride.pickup_address} class="text-sm text-base-content/70">
                {@request.ride.pickup_address}
              </p>
              <p :if={@request.status != "accepted"} class="text-xs text-base-content/50">
                General Area (exact address shared after acceptance)
              </p>
            </div>
            
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-flag" class="w-4 h-4" /> Destination
              </h3>
              <p class="font-semibold text-base-content">{@request.ride.destination_name}</p>
              <p :if={@request.status == "accepted" && @request.ride.destination_address} class="text-sm text-base-content/70">
                {@request.ride.destination_address}
              </p>
              <p :if={@request.status != "accepted"} class="text-xs text-base-content/50">
                General Area (exact address shared after acceptance)
              </p>
            </div>
          </div>
          
          <div class="space-y-4">
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-clock" class="w-4 h-4" /> Date & Time
              </h3>
              <p class="font-semibold text-base-content">
                {Calendar.strftime(@request.ride.ride_date, "%A, %B %d, %Y")}
              </p>
              <p class="text-sm text-base-content/70">
                {Calendar.strftime(@request.ride.ride_date, "%I:%M %p")}
              </p>
            </div>
            
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-user" class="w-4 h-4" /> Rider Contact
              </h3>
              <p class="font-semibold text-base-content">{@request.ride.user.email}</p>
              <p class="text-sm text-base-content/70">{@request.ride.user.phone}</p>
            </div>
          </div>
        </div>

        <!-- Your Message -->
        <div :if={@request.message && @request.message != ""} class="mb-6">
          <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
            <.icon name="hero-document-text" class="w-4 h-4" /> Your Message
          </h3>
          <p class="text-sm text-base-content bg-base-200 p-4 rounded-lg italic">
            "{@request.message}"
          </p>
        </div>

        <!-- Ride Description -->
        <div :if={@request.ride.description && @request.ride.description != ""} class="mb-6">
          <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
            <.icon name="hero-chat-bubble-bottom-center-text" class="w-4 h-4" /> Rider's Notes
          </h3>
          <p class="text-sm text-base-content bg-base-200 p-4 rounded-lg">
            {@request.ride.description}
          </p>
        </div>

        <!-- Map (for accepted requests) -->
        <div :if={@request.status == "accepted"} class="mb-6">
          <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
            <.icon name="hero-map" class="w-4 h-4" /> Exact Locations
          </h3>
          <.exact_location_map ride={@request.ride} class="h-64 rounded-lg" />
        </div>

        <!-- Actions -->
        <div class="flex justify-between items-center pt-6 border-t">
          <button 
            phx-click="hide_request_details"
            class="btn btn-ghost"
          >
            Close
          </button>
          
          <div class="flex items-center gap-2">
            <.link 
              :if={@request.status == "accepted" && @request.ride.conversation}
              navigate={~p"/dashboard/chat/#{@request.ride.conversation.id}"} 
              class="btn btn-primary flex items-center gap-2"
            >
              <.icon name="hero-chat-bubble-left-right" class="w-4 h-4" />
              Chat with Rider
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
