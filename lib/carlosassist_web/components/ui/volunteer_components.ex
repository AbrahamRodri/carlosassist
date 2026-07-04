defmodule CarlosassistWeb.UI.VolunteerComponents do
  use Phoenix.Component
  import CarlosassistWeb.CoreComponents
  import CarlosassistWeb.UI.MapComponents
  use CarlosassistWeb, :verified_routes

  alias Carlosassist.Accounts.User

  @doc """
  Renders the volunteer requests section showing all offers made by the volunteer.
  """
  attr :requests, :list, required: true

  def volunteer_requests_section(assigns) do
    ~H"""
    <div :if={@requests == []} class="text-center py-8">
      <p class="text-base text-base-content/75">
        You haven't offered to drive anyone yet. When you do, your offers will
        show up here.
      </p>
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
    <div class="p-4 bg-base-100 rounded-xl border-2 border-base-300">
      <div class="flex items-start gap-3">
        <.avatar src={@request.ride.user.profile_pic_location} alt="Rider's photo" size="sm" />
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between gap-2 mb-2">
            <.request_status_badge status={@request.status} />
            <.link
              :if={@request.status == "accepted" && @request.ride.conversation}
              navigate={~p"/dashboard/chat/#{@request.ride.conversation.id}"}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-chat-bubble-left-right" class="w-4 h-4" /> Message
            </.link>
          </div>

          <button
            class="w-full text-left cursor-pointer hover:bg-base-200/60 -m-1 p-1 rounded-lg"
            phx-click="show_request_details"
            phx-value-request_id={@request.id}
          >
            <p class="text-base font-bold text-base-content leading-snug mb-1">
              {User.display_name(@request.ride.user)}
            </p>
            <p class="text-base text-base-content/80 leading-snug">
              {@request.ride.pickup_name}
              <.icon name="hero-arrow-right" class="w-3.5 h-3.5 inline mx-0.5 text-base-content/50" />
              {@request.ride.destination_name}
            </p>

            <div class="flex items-center justify-between mt-2">
              <p class="text-base text-base-content/70">
                {Calendar.strftime(@request.ride.ride_date, "%b %d, %I:%M %p")}
              </p>
              <span class="text-base font-bold text-primary flex items-center gap-1">
                Details <.icon name="hero-chevron-right" class="w-4 h-4" />
              </span>
            </div>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a single ride browser, one request at a time with big navigation buttons.
  """
  attr :rides, :list, required: true
  attr :current_index, :integer, required: true

  def single_ride_browser(assigns) do
    ~H"""
    <div :if={@rides == []} class="text-center py-12">
      <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
        <.icon name="hero-heart" class="w-8 h-8 text-primary" />
      </div>
      <p class="text-lg text-base-content/80 max-w-sm mx-auto">
        No one is waiting for a ride right now. Thank you for checking in —
        please come back soon.
      </p>
    </div>
    <div :if={@rides != []}>
      <% current_ride = Enum.at(@rides, @current_index) %>

      <p :if={length(@rides) > 1} class="text-center text-base font-bold text-base-content/75 mb-4">
        Request {@current_index + 1} of {length(@rides)}
      </p>

      <!-- Single ride card -->
      <div class="bg-base-100 border-2 border-base-300 rounded-xl p-5 sm:p-6">
        <div class="flex items-start gap-4 mb-5">
          <.avatar src={current_ride.user.profile_pic_location} alt="Rider's photo" size="xl" />
          <div class="flex-1">
            <h3 class="text-2xl text-base-content">
              {User.display_name(current_ride.user)}
            </h3>
            <p class="text-base text-base-content/75">needs a ride</p>
          </div>
        </div>

        <.ride_details ride={current_ride} />

        <!-- Actions -->
        <div class="mt-6 pt-5 border-t-2 border-base-300">
          <button
            phx-click="request_ride"
            phx-value-ride_id={current_ride.id}
            class="btn btn-primary btn-lg w-full mb-3"
          >
            <.icon name="hero-heart" class="w-6 h-6" />
            I can drive {User.first_name(current_ride.user)}
          </button>

          <div :if={length(@rides) > 1} class="flex justify-between items-center">
            <button phx-click="previous_ride" class="btn btn-ghost">
              <.icon name="hero-chevron-left" class="w-5 h-5" /> Previous request
            </button>
            <button phx-click="next_ride" class="btn btn-ghost">
              Next request <.icon name="hero-chevron-right" class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
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
    selected = Enum.find(assigns.rides, fn ride -> ride.id == assigns.selected_ride end)
    assigns = assign(assigns, :ride, selected)

    ~H"""
    <div
      class="fixed inset-0 bg-black/50 overflow-y-auto h-full w-full z-50"
      phx-key="Escape"
      phx-window-keydown="close_modal"
    >
      <div
        class="relative top-16 mx-auto p-6 sm:p-8 w-full max-w-lg parish-card m-4"
        phx-click-away="close_modal"
      >
        <h3 class="text-2xl text-base-content mb-4">
          {if @ride, do: "Offer to drive #{User.first_name(@ride.user)}", else: "Offer to help"}
        </h3>

        <div :if={@ride} class="bg-base-200 border-2 border-base-300 p-4 rounded-xl mb-5">
          <p class="text-lg font-bold text-base-content">
            {@ride.pickup_name}
            <.icon name="hero-arrow-right" class="w-4 h-4 inline mx-1 text-base-content/50" />
            {@ride.destination_name}
          </p>
          <p class="text-base text-base-content/75">
            {Calendar.strftime(@ride.ride_date, "%A, %B %d at %I:%M %p")}
          </p>
        </div>

        <p class="text-base text-base-content/75 mb-4">
          {if @ride, do: User.first_name(@ride.user), else: "The rider"} will see your name,
          photo, and car — and this note, if you'd like to add one.
        </p>

        <label for="volunteer-message" class="block text-lg font-bold text-base-content mb-2">
          A short note <span class="font-normal text-base-content/60">(optional)</span>
        </label>
        <textarea
          id="volunteer-message"
          phx-hook="TextareaAutosize"
          phx-update="ignore"
          rows="3"
          class="textarea textarea-bordered w-full text-lg"
          placeholder="For example: Happy to help! I can also give you a hand with bags."
          phx-change="update_message"
          value={@request_message}
        ></textarea>

        <div class="flex flex-col sm:flex-row gap-3 mt-6">
          <button phx-click="close_modal" class="btn btn-outline btn-lg flex-1">
            Never mind
          </button>
          <button
            phx-click="submit_request"
            phx-value-message={@request_message}
            class="btn btn-primary btn-lg flex-1"
          >
            <.icon name="hero-paper-airplane" class="w-5 h-5" /> Send my offer
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Private helper components

  defp request_status_badge(assigns) do
    ~H"""
    <div class={[
      "px-3 py-1 rounded-full text-base font-bold border-2",
      @status == "pending" && "bg-warning/15 text-warning border-warning/40",
      @status == "accepted" && "bg-success/15 text-success border-success/40",
      @status == "rejected" && "bg-base-200 text-base-content/70 border-base-300"
    ]}>
      {format_offer_status(@status)}
    </div>
    """
  end

  defp format_offer_status("pending"), do: "Waiting for reply"
  defp format_offer_status("accepted"), do: "You're the driver!"
  defp format_offer_status("rejected"), do: "Not this time"
  defp format_offer_status(status), do: String.capitalize(status)

  defp ride_details(assigns) do
    ~H"""
    <!-- Privacy notice for volunteers -->
    <div class="bg-base-200 border-2 border-base-300 p-3 rounded-xl mb-5">
      <p class="text-base text-base-content/80 flex items-start gap-2">
        <.icon name="hero-lock-closed" class="w-5 h-5 mt-0.5 shrink-0 text-accent" />
        <span>
          For the rider's privacy, exact addresses are shared only after they choose you
          as their driver.
        </span>
      </p>
    </div>

    <div class="grid sm:grid-cols-2 gap-4 mb-5">
      <div>
        <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
          <.icon name="hero-map-pin" class="w-5 h-5" /> Picking up from
        </p>
        <p class="text-lg font-bold text-base-content">{@ride.pickup_name}</p>
        <p class="text-base text-base-content/70">General area, about a half-mile around</p>
      </div>
      <div>
        <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
          <.icon name="hero-flag" class="w-5 h-5" /> Going to
        </p>
        <p class="text-lg font-bold text-base-content">{@ride.destination_name}</p>
        <p class="text-base text-base-content/70">General area, about a half-mile around</p>
      </div>
    </div>

    <div class="mb-5">
      <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
        <.icon name="hero-calendar" class="w-5 h-5" /> When
      </p>
      <p class="text-lg font-bold text-base-content">
        {Calendar.strftime(@ride.ride_date, "%A, %B %d at %I:%M %p")}
      </p>
    </div>

    <div :if={@ride.description && @ride.description != ""} class="mb-5">
      <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
        <.icon name="hero-document-text" class="w-5 h-5" /> Their note
      </p>
      <p class="text-base text-base-content bg-base-200 p-3 rounded-lg">{@ride.description}</p>
    </div>

    <!-- Privacy Radius Map Preview -->
    <div class="mb-2">
      <p class="text-base font-bold text-base-content/70 mb-2 flex items-center gap-2">
        <.icon name="hero-map" class="w-5 h-5" /> The general area
      </p>
      <.privacy_radius_map ride={@ride} location_type={:pickup} class="h-64" />
    </div>
    """
  end

  @doc """
  Renders the request details modal for volunteer's own offers.
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
        class="relative top-8 mx-auto p-6 sm:p-8 w-full max-w-3xl parish-card m-4"
        phx-click-away="hide_request_details"
      >
        <!-- Header -->
        <div class="flex justify-between items-start mb-6">
          <div class="flex items-center gap-4">
            <.avatar src={@request.ride.user.profile_pic_location} alt="Rider's photo" size="lg" />
            <div>
              <h2 class="text-2xl text-base-content mb-1">
                Driving {User.display_name(@request.ride.user)}
              </h2>
              <.request_status_badge status={@request.status} />
            </div>
          </div>
          <button phx-click="hide_request_details" class="btn btn-ghost">
            <.icon name="hero-x-mark" class="w-5 h-5" /> Close
          </button>
        </div>

        <!-- Status explanation -->
        <div class="mb-6">
          <div
            :if={@request.status == "pending"}
            class="bg-warning/10 border-2 border-warning/30 p-4 rounded-xl"
          >
            <p class="text-lg font-bold text-warning flex items-center gap-2">
              <.icon name="hero-clock" class="w-5 h-5" /> Waiting for a reply
            </p>
            <p class="text-base text-base-content/80 mt-1">
              {User.first_name(@request.ride.user)} hasn't chosen a driver yet.
              We'll show it here as soon as they decide.
            </p>
          </div>

          <div
            :if={@request.status == "accepted"}
            class="bg-success/10 border-2 border-success/30 p-4 rounded-xl"
          >
            <p class="text-lg font-bold text-success flex items-center gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5" /> You're the driver!
            </p>
            <p class="text-base text-base-content/80 mt-1">
              {User.first_name(@request.ride.user)} chose you for this ride.
              The exact addresses are now shown below.
            </p>
          </div>

          <div
            :if={@request.status == "rejected"}
            class="bg-base-200 border-2 border-base-300 p-4 rounded-xl"
          >
            <p class="text-lg font-bold text-base-content flex items-center gap-2">
              <.icon name="hero-heart" class="w-5 h-5" /> Not this time
            </p>
            <p class="text-base text-base-content/80 mt-1">
              The rider went with someone else for this trip — but thank you for
              offering. It means a lot.
            </p>
          </div>
        </div>

        <!-- Ride Information -->
        <div class="grid md:grid-cols-2 gap-6 mb-6">
          <div class="space-y-5">
            <div>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-map-pin" class="w-5 h-5" /> Picking up from
              </h3>
              <p class="text-lg font-bold text-base-content">{@request.ride.pickup_name}</p>
              <p
                :if={@request.status == "accepted" && @request.ride.pickup_address}
                class="text-base text-base-content/75"
              >
                {@request.ride.pickup_address}
              </p>
              <p :if={@request.status != "accepted"} class="text-base text-base-content/70">
                Exact address shared if you're chosen
              </p>
            </div>

            <div>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-flag" class="w-5 h-5" /> Going to
              </h3>
              <p class="text-lg font-bold text-base-content">{@request.ride.destination_name}</p>
              <p
                :if={@request.status == "accepted" && @request.ride.destination_address}
                class="text-base text-base-content/75"
              >
                {@request.ride.destination_address}
              </p>
              <p :if={@request.status != "accepted"} class="text-base text-base-content/70">
                Exact address shared if you're chosen
              </p>
            </div>
          </div>

          <div class="space-y-5">
            <div>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-calendar" class="w-5 h-5" /> When
              </h3>
              <p class="text-lg font-bold text-base-content">
                {Calendar.strftime(@request.ride.ride_date, "%A, %B %d, %Y")}
              </p>
              <p class="text-base text-base-content/75">
                at {Calendar.strftime(@request.ride.ride_date, "%I:%M %p")}
              </p>
            </div>

            <div :if={@request.status == "accepted"}>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-phone" class="w-5 h-5" /> Reaching {User.first_name(
                  @request.ride.user
                )}
              </h3>
              <p class="text-lg font-bold text-base-content">{@request.ride.user.phone}</p>
              <p class="text-base text-base-content/75">{@request.ride.user.email}</p>
            </div>
          </div>
        </div>

        <!-- Your note -->
        <div :if={@request.message && @request.message != ""} class="mb-6">
          <h3 class="text-base font-bold text-base-content/70 mb-2 flex items-center gap-2">
            <.icon name="hero-document-text" class="w-5 h-5" /> Your note to them
          </h3>
          <p class="text-lg font-display italic text-base-content bg-base-200 p-4 rounded-xl">
            “{@request.message}”
          </p>
        </div>

        <!-- Rider's note -->
        <div :if={@request.ride.description && @request.ride.description != ""} class="mb-6">
          <h3 class="text-base font-bold text-base-content/70 mb-2 flex items-center gap-2">
            <.icon name="hero-chat-bubble-bottom-center-text" class="w-5 h-5" /> Their note
          </h3>
          <p class="text-base text-base-content bg-base-200 p-4 rounded-xl">
            {@request.ride.description}
          </p>
        </div>

        <!-- Map (for accepted requests) -->
        <div :if={@request.status == "accepted"} class="mb-6">
          <h3 class="text-base font-bold text-base-content/70 mb-2 flex items-center gap-2">
            <.icon name="hero-map" class="w-5 h-5" /> Where you're going
          </h3>
          <.exact_location_map ride={@request.ride} class="h-64 rounded-xl" />
        </div>

        <!-- Actions -->
        <div class="flex flex-col sm:flex-row justify-between gap-3 pt-6 border-t-2 border-base-300">
          <button phx-click="hide_request_details" class="btn btn-outline">
            Close
          </button>

          <.link
            :if={@request.status == "accepted" && @request.ride.conversation}
            navigate={~p"/dashboard/chat/#{@request.ride.conversation.id}"}
            class="btn btn-primary"
          >
            <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" />
            Message {User.first_name(@request.ride.user)}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
