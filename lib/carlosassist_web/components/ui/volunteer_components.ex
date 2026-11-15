defmodule CarlosassistWeb.UI.VolunteerComponents do
  @moduledoc """
  The volunteer dashboard's parts: the rides that need a driver, shown one at
  a time; the volunteer's own offers; the modal for sending an offer; and the
  modal with the details of one offer.
  """
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
    <p :if={@requests == []} class="muted">
      You have not offered to drive any ride yet.
    </p>
    <div :if={@requests != []} class="grid gap-4">
      <.simplified_volunteer_request_card :for={request <- @requests} request={request} />
    </div>
    """
  end

  @doc """
  Renders a simplified volunteer request card with minimal information.
  """
  attr :request, :map, required: true

  def simplified_volunteer_request_card(assigns) do
    assigns = assign(assigns, :conversation, conversation(assigns.request))

    ~H"""
    <article class="sheet">
      <.request_status_badge status={@request.status} />
      <h3 class="card-title mt-3">
        {@request.ride.pickup_name} to {@request.ride.destination_name}
      </h3>
      <p class="muted small mt-1">{format_ride_date(@request.ride.ride_date)}</p>

      <div class="btn-row mt-5">
        <.link
          :if={@request.status == "accepted" && @conversation}
          navigate={~p"/dashboard/chat/#{@conversation.id}"}
          class="btn btn-gold"
        >
          <.icon name="hero-chat-bubble-left-right" class="size-6" /> Message the rider
        </.link>
        <button
          phx-click="show_request_details"
          phx-value-request_id={@request.id}
          class="btn btn-outline"
        >
          See the details
        </button>
      </div>
    </article>
    """
  end

  @doc """
  Renders a single volunteer request card.
  """
  attr :request, :map, required: true

  def volunteer_request_card(assigns) do
    ~H"""
    <article class="sheet">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div class="flex items-center gap-4">
          <.avatar src={@request.ride.user.profile_pic_location} alt="Photo of the rider" size="md" />
          <div>
            <h3 class="card-title">
              {@request.ride.pickup_name} to {@request.ride.destination_name}
            </h3>
            <p class="muted small">{format_ride_date(@request.ride.ride_date)}</p>
          </div>
        </div>
        <.request_status_badge status={@request.status} />
      </div>
      <div :if={@request.message} class="mt-4">
        <p class="data-label">Your message</p>
        <p class="quote mt-1">{@request.message}</p>
      </div>
      <.accepted_request_info :if={@request.status == "accepted"} request={@request} />
      <.rejected_request_info :if={@request.status == "rejected"} />
    </article>
    """
  end

  @doc """
  Renders the available rides section for volunteers to browse.
  """
  attr :rides, :list, required: true

  def available_rides_section(assigns) do
    ~H"""
    <p :if={@rides == []} class="muted">
      No one is waiting for a ride right now.
    </p>
    <div :if={@rides != []} class="grid gap-6">
      <.available_ride_card :for={ride <- @rides} ride={ride} />
    </div>
    """
  end

  @doc """
  Renders the rides that need a driver, one at a time, with buttons to move
  to the previous and the next one.
  """
  attr :rides, :list, required: true
  attr :current_index, :integer, required: true

  def single_ride_browser(assigns) do
    ~H"""
    <div :if={@rides == []} class="sheet text-center">
      <h3 class="card-title">No one is waiting for a ride right now</h3>
      <.divider />
      <p class="muted">Please look again later.</p>
    </div>
    <div :if={@rides != []}>
      <% current_ride = Enum.at(@rides, @current_index) %>

      <div :if={length(@rides) > 1} class="mb-4 flex items-center justify-between gap-3">
        <button phx-click="previous_ride" class="btn btn-outline" aria-label="Previous ride">
          <.icon name="hero-chevron-left" class="size-6" />
          <span class="hidden sm:inline">Previous</span>
        </button>
        <span class="muted">Ride {@current_index + 1} of {length(@rides)}</span>
        <button phx-click="next_ride" class="btn btn-outline" aria-label="Next ride">
          <span class="hidden sm:inline">Next</span>
          <.icon name="hero-chevron-right" class="size-6" />
        </button>
      </div>

      <article class="sheet">
        <p class="kicker mb-1">{format_ride_date(current_ride.ride_date)}</p>
        <h3 class="page-title">
          {current_ride.pickup_name} to {current_ride.destination_name}
        </h3>

        <div class="mt-5 flex items-center gap-4">
          <.avatar src={current_ride.user.profile_pic_location} alt="Photo of the rider" size="lg" />
          <div class="min-w-0">
            <p class="data-label">Rider</p>
            <p class="data-value">{current_ride.user.email}</p>
            <p class="data-note">{current_ride.user.phone}</p>
          </div>
        </div>

        <hr class="sheet-rule" />

        <.ride_details ride={current_ride} />

        <hr class="sheet-rule" />

        <button
          phx-click="request_ride"
          phx-value-ride_id={current_ride.id}
          class="btn btn-gold btn-lg btn-block"
        >
          <.icon name="hero-hand-raised" class="size-6" /> Offer to drive
        </button>
      </article>
    </div>
    """
  end

  @doc """
  Renders a single available ride card.
  """
  attr :ride, :map, required: true

  def available_ride_card(assigns) do
    ~H"""
    <article class="sheet">
      <div class="mb-5 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <.avatar src={@ride.user.profile_pic_location} alt="Photo of the rider" size="lg" />
          <div class="min-w-0">
            <p class="data-label">Rider</p>
            <p class="data-value">{@ride.user.email}</p>
            <p class="data-note">{@ride.user.phone}</p>
          </div>
        </div>
        <button phx-click="request_ride" phx-value-ride_id={@ride.id} class="btn btn-gold">
          Offer to drive
        </button>
      </div>

      <.ride_details ride={@ride} />
    </article>
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
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="offer-title"
      phx-key="Escape"
      phx-window-keydown="close_modal"
    >
      <div class="sheet modal-sheet modal-sheet-narrow" phx-click-away="close_modal">
        <div class="modal-head">
          <div>
            <p class="kicker mb-1">Your offer</p>
            <h2 id="offer-title" class="page-title">Offer to drive</h2>
          </div>
          <button phx-click="close_modal" class="btn-icon" aria-label="Close">
            <.icon name="hero-x-mark" class="size-7" />
          </button>
        </div>

        <.selected_ride_info selected_ride={@selected_ride} rides={@rides} />

        <div class="notice mb-6">
          <.icon name="hero-information-circle" />
          <p>The rider sees your photo, your car and your message.</p>
        </div>

        <div class="field">
          <label for="volunteer-message" class="field-label">
            A message for the rider (you can leave this empty)
          </label>
          <textarea
            id="volunteer-message"
            phx-update="ignore"
            rows="3"
            class="field-input"
            placeholder="I can take you, and I can help you to the door."
            phx-change="update_message"
            value={@request_message}
          ></textarea>
        </div>

        <div class="flex flex-col-reverse gap-3 sm:flex-row">
          <button phx-click="close_modal" class="btn btn-outline sm:flex-1">
            Cancel
          </button>
          <button
            phx-click="submit_request"
            phx-value-message={@request_message}
            class="btn btn-gold sm:flex-1"
          >
            Send my offer
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Private helper components

  defp request_status_badge(assigns) do
    ~H"""
    <span class={[
      "badge",
      @status == "pending" && "badge-caution",
      @status == "accepted" && "badge-positive",
      @status == "rejected" && "badge-danger"
    ]}>
      {request_status_text(@status)}
    </span>
    """
  end

  defp request_status_text("pending"), do: "Waiting for the rider"
  defp request_status_text("accepted"), do: "The rider chose you"
  defp request_status_text("rejected"), do: "Not chosen"
  defp request_status_text(status), do: String.capitalize(status)

  defp accepted_request_info(assigns) do
    assigns = assign(assigns, :conversation, conversation(assigns.request))

    ~H"""
    <div class="mt-5">
      <div class="notice notice-positive mb-5">
        <.icon name="hero-check-circle" />
        <p><strong>The rider chose you.</strong> You can now see the exact addresses.</p>
      </div>

      <div class="data-grid mb-5">
        <.datum label="Rider's email">{@request.ride.user.email}</.datum>
        <.datum label="Rider's phone">{@request.ride.user.phone}</.datum>
        <.datum label="Pickup" icon="hero-map-pin">
          {@request.ride.pickup_address || @request.ride.pickup_name}
        </.datum>
        <.datum label="Going to" icon="hero-flag">
          {@request.ride.destination_address || @request.ride.destination_name}
        </.datum>
      </div>

      <.exact_location_map ride={@request.ride} class="h-64" />

      <.link
        :if={@conversation}
        navigate={~p"/dashboard/chat/#{@conversation.id}"}
        class="btn btn-gold mt-5"
      >
        <.icon name="hero-chat-bubble-left-right" class="size-6" /> Message the rider
      </.link>
    </div>
    """
  end

  defp rejected_request_info(assigns) do
    ~H"""
    <div class="notice notice-danger mt-5">
      <.icon name="hero-x-circle" />
      <p>The rider chose another driver this time. Thank you for offering.</p>
    </div>
    """
  end

  defp ride_details(assigns) do
    ~H"""
    <div class="data-grid">
      <.datum label="Pickup" icon="hero-map-pin">
        {@ride.pickup_name}
        <:note>General area only</:note>
      </.datum>
      <.datum label="Going to" icon="hero-flag">
        {@ride.destination_name}
        <:note>General area only</:note>
      </.datum>
      <.datum label="Day and time" icon="hero-clock" class="data-span">
        {format_ride_date(@ride.ride_date)}
      </.datum>
      <div :if={@ride.description && @ride.description != ""} class="data-span">
        <p class="data-label">
          <.icon name="hero-document-text" class="size-5" /> Note from the rider
        </p>
        <p class="quote mt-1">{@ride.description}</p>
      </div>
    </div>

    <div class="mt-6">
      <p class="data-label mb-2"><.icon name="hero-map" class="size-5" /> Pickup area</p>
      <.privacy_radius_map ride={@ride} location_type={:pickup} class="h-64" />
    </div>

    <div class="notice mt-5">
      <.icon name="hero-lock-closed" />
      <p>You see the exact addresses once the rider chooses you.</p>
    </div>
    """
  end

  defp selected_ride_info(assigns) do
    ~H"""
    <% selected_ride = Enum.find(@rides, fn ride -> ride.id == @selected_ride end) %>
    <div :if={selected_ride} class="inset mb-6">
      <p class="data-value">
        {selected_ride.pickup_name} to {selected_ride.destination_name}
      </p>
      <p class="data-note">{format_ride_date(selected_ride.ride_date)}</p>
    </div>
    """
  end

  @doc """
  Renders the request details modal for volunteer's own requests.
  """
  attr :request, :map, required: true

  def volunteer_request_details_modal(assigns) do
    assigns = assign(assigns, :conversation, conversation(assigns.request))

    ~H"""
    <div
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="offer-details-title"
      phx-key="Escape"
      phx-window-keydown="hide_request_details"
    >
      <div class="sheet modal-sheet" phx-click-away="hide_request_details">
        <div class="modal-head">
          <div>
            <p class="kicker mb-1">Your offer</p>
            <h2 id="offer-details-title" class="page-title">
              {@request.ride.pickup_name} to {@request.ride.destination_name}
            </h2>
            <div class="mt-3"><.request_status_badge status={@request.status} /></div>
          </div>
          <button phx-click="hide_request_details" class="btn-icon" aria-label="Close">
            <.icon name="hero-x-mark" class="size-7" />
          </button>
        </div>

        <div :if={@request.status == "pending"} class="notice notice-caution mb-6">
          <.icon name="hero-clock" />
          <p>The rider has not chosen a driver yet.</p>
        </div>

        <div :if={@request.status == "accepted"} class="notice notice-positive mb-6">
          <.icon name="hero-check-circle" />
          <p><strong>The rider chose you.</strong> You can now see the exact addresses.</p>
        </div>

        <div :if={@request.status == "rejected"} class="notice notice-danger mb-6">
          <.icon name="hero-x-circle" />
          <p>The rider chose another driver this time. Thank you for offering.</p>
        </div>

        <div class="data-grid">
          <.datum label="Pickup" icon="hero-map-pin">
            {@request.ride.pickup_name}
            <:note :if={@request.status == "accepted" && @request.ride.pickup_address}>
              {@request.ride.pickup_address}
            </:note>
            <:note :if={@request.status != "accepted"}>
              General area only
            </:note>
          </.datum>

          <.datum label="Going to" icon="hero-flag">
            {@request.ride.destination_name}
            <:note :if={@request.status == "accepted" && @request.ride.destination_address}>
              {@request.ride.destination_address}
            </:note>
            <:note :if={@request.status != "accepted"}>
              General area only
            </:note>
          </.datum>

          <.datum label="Day and time" icon="hero-clock">
            {format_ride_date(@request.ride.ride_date)}
          </.datum>

          <.datum label="Rider" icon="hero-user">
            {@request.ride.user.email}
            <:note>{@request.ride.user.phone}</:note>
          </.datum>

          <div :if={@request.message && @request.message != ""} class="data-span">
            <p class="data-label">
              <.icon name="hero-chat-bubble-bottom-center-text" class="size-5" /> Your message
            </p>
            <p class="quote mt-1">"{@request.message}"</p>
          </div>

          <div :if={@request.ride.description && @request.ride.description != ""} class="data-span">
            <p class="data-label">
              <.icon name="hero-document-text" class="size-5" /> Note from the rider
            </p>
            <p class="quote mt-1">{@request.ride.description}</p>
          </div>
        </div>

        <div :if={@request.status == "accepted"} class="mt-6">
          <p class="data-label mb-2"><.icon name="hero-map" class="size-5" /> Map</p>
          <.exact_location_map ride={@request.ride} class="h-64" />
        </div>

        <hr class="sheet-rule" />

        <div class="btn-row btn-row-between">
          <.link
            :if={@request.status == "accepted" && @conversation}
            navigate={~p"/dashboard/chat/#{@conversation.id}"}
            class="btn btn-gold"
          >
            <.icon name="hero-chat-bubble-left-right" class="size-6" /> Message the rider
          </.link>
          <button phx-click="hide_request_details" class="btn btn-outline sm:ml-auto">
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  # The dashboard puts the ride's conversation on the ride when it loads the
  # requests; a request loaded elsewhere has none.
  defp conversation(request), do: Map.get(request.ride, :conversation)

  defp format_ride_date(datetime), do: Calendar.strftime(datetime, "%A, %B %-d at %-I:%M %p")
end
