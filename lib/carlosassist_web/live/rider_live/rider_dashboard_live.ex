defmodule CarlosassistWeb.RiderDashboardLive do
  @moduledoc """
  Rider home (`/dashboard/rider`): 4-step ride-request wizard (state in
  `:wizard_data`, submitted as hidden inputs at step 4) plus the rider's rides
  grouped by status. Each ride is a card; its details open in a modal, where
  the rider looks at the volunteers' offers and accepts or refuses them. Not PubSub-subscribed —
  new offers show up on refresh. Template: rider_dashboard_live.html.heex;
  wizard/card markup lives in function components below.
  """
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
     |> assign(:wizard_step, 1)
     |> assign(:wizard_data, %{})
     |> assign(:volunteer_indices, %{})
     |> assign(:show_ride_details, false)
     |> assign(:selected_ride, nil)
     |> load_rides()}
  end

  def handle_event("show_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:wizard_step, 1)
     |> assign(:wizard_data, %{})}
  end

  def handle_event("hide_form", _params, socket) do
    changeset = Rides.change_ride(%Ride{})

    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:wizard_step, 1)
     |> assign(:wizard_data, %{})
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("next_step", %{"step_data" => step_data}, socket) do
    current_step = socket.assigns.wizard_step
    wizard_data = Map.merge(socket.assigns.wizard_data, step_data)

    {:noreply,
     socket
     |> assign(:wizard_step, current_step + 1)
     |> assign(:wizard_data, wizard_data)}
  end

  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.wizard_step

    {:noreply, assign(socket, :wizard_step, max(1, current_step - 1))}
  end

  def handle_event("validate", %{"ride" => ride_params}, socket) do
    changeset =
      %Ride{}
      |> Rides.change_ride(ride_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event(
        "update_coordinates",
        %{"type" => type, "address" => address, "lat" => lat, "lng" => lng},
        socket
      ) do
    current_params = socket.assigns.form.params || %{}

    updated_params =
      case type do
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

    # ALSO update wizard_data with coordinates
    updated_wizard_data =
      case type do
        "pickup" ->
          Map.merge(socket.assigns.wizard_data, %{
            "pickup_address" => address,
            "pickup_lat" => lat,
            "pickup_long" => lng
          })

        "destination" ->
          Map.merge(socket.assigns.wizard_data, %{
            "destination_address" => address,
            "destination_lat" => lat,
            "destination_long" => lng
          })
      end

    changeset =
      %Ride{}
      |> Rides.change_ride(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:wizard_data, updated_wizard_data)}
  end

  def handle_event("clear_coordinates", %{"type" => type}, socket) do
    current_params = socket.assigns.form.params || %{}

    updated_params =
      case type do
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

    # ALSO clear wizard_data coordinates
    updated_wizard_data =
      case type do
        "pickup" ->
          socket.assigns.wizard_data
          |> Map.delete("pickup_lat")
          |> Map.delete("pickup_long")

        "destination" ->
          socket.assigns.wizard_data
          |> Map.delete("destination_lat")
          |> Map.delete("destination_long")
      end

    changeset =
      %Ride{}
      |> Rides.change_ride(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:wizard_data, updated_wizard_data)}
  end

  def handle_event("save", %{"ride" => ride_params}, socket) do
    # Merge wizard data if available, otherwise use form params
    final_params =
      if socket.assigns.wizard_data != %{} do
        Map.merge(socket.assigns.wizard_data, ride_params)
      else
        ride_params
      end

    case Rides.create_ride(final_params, socket.assigns.current_scope) do
      {:ok, ride} ->
        rides = [ride | socket.assigns.rides]
        changeset = Rides.change_ride(%Ride{})

        {:noreply,
         socket
         |> put_flash(:info, "Your ride request has been posted successfully!")
         |> assign(:rides, rides)
         |> assign(:form, to_form(changeset))
         |> assign(:show_form, false)
         |> assign(:wizard_step, 1)
         |> assign(:wizard_data, %{})}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    ride = Rides.get_ride_for_user!(id, socket.assigns.current_scope)

    case Rides.delete_ride(ride, socket.assigns.current_scope) do
      {:ok, _ride} ->
        rides = Enum.filter(socket.assigns.rides, &(&1.id != String.to_integer(id)))

        {:noreply,
         socket
         |> put_flash(:info, "Ride deleted successfully!")
         |> assign(:rides, rides)
         |> assign(:show_ride_details, false)
         |> assign(:selected_ride, nil)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete ride.")}
    end
  end

  def handle_event(
        "accept_volunteer",
        %{"request_id" => request_id, "ride_id" => ride_id},
        socket
      ) do
    case Rides.accept_volunteer_request(
           String.to_integer(request_id),
           String.to_integer(ride_id),
           socket.assigns.current_scope
         ) do
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
    case Rides.reject_volunteer_request(
           String.to_integer(request_id),
           socket.assigns.current_scope
         ) do
      {:ok, _rejected_request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Volunteer request rejected.")
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reject volunteer request.")}
    end
  end

  def handle_event("complete_ride", %{"ride_id" => ride_id}, socket) do
    case Rides.complete_ride(String.to_integer(ride_id), socket.assigns.current_scope) do
      {:ok, _ride} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ride marked as completed!")
         |> assign(:show_ride_details, false)
         |> assign(:selected_ride, nil)
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete this ride.")}
    end
  end

  def handle_event("cancel_ride", %{"ride_id" => ride_id}, socket) do
    case Rides.cancel_ride(String.to_integer(ride_id), socket.assigns.current_scope) do
      {:ok, _ride} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ride cancelled.")
         |> assign(:show_ride_details, false)
         |> assign(:selected_ride, nil)
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not cancel this ride.")}
    end
  end

  def handle_event("next_volunteer", %{"ride_id" => ride_id}, socket) do
    ride_id = String.to_integer(ride_id)
    current_indices = socket.assigns.volunteer_indices
    current_index = Map.get(current_indices, ride_id, 0)

    # Find the ride to get volunteer count
    ride = Enum.find(socket.assigns.rides, &(&1.id == ride_id))

    volunteer_count =
      if ride && ride.volunteer_requests, do: length(ride.volunteer_requests), else: 0

    new_index = if current_index + 1 >= volunteer_count, do: 0, else: current_index + 1
    updated_indices = Map.put(current_indices, ride_id, new_index)

    {:noreply, assign(socket, :volunteer_indices, updated_indices)}
  end

  def handle_event("previous_volunteer", %{"ride_id" => ride_id}, socket) do
    ride_id = String.to_integer(ride_id)
    current_indices = socket.assigns.volunteer_indices
    current_index = Map.get(current_indices, ride_id, 0)

    # Find the ride to get volunteer count
    ride = Enum.find(socket.assigns.rides, &(&1.id == ride_id))

    volunteer_count =
      if ride && ride.volunteer_requests, do: length(ride.volunteer_requests), else: 0

    new_index = if current_index - 1 < 0, do: max(0, volunteer_count - 1), else: current_index - 1
    updated_indices = Map.put(current_indices, ride_id, new_index)

    {:noreply, assign(socket, :volunteer_indices, updated_indices)}
  end

  def handle_event("show_ride_details", %{"ride_id" => ride_id}, socket) do
    ride = Enum.find(socket.assigns.rides, &(&1.id == String.to_integer(ride_id)))

    {:noreply,
     socket
     |> assign(:show_ride_details, true)
     |> assign(:selected_ride, ride)}
  end

  def handle_event("hide_ride_details", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_ride_details, false)
     |> assign(:selected_ride, nil)}
  end

  # The render function is now handled by the corresponding .html.heex template

  # Private helper functions
  defp load_rides(socket) do
    rides = Rides.list_rides_for_user(socket.assigns.current_scope)
    # Get volunteer requests for each ride and conversation info
    rides_with_requests =
      Enum.map(rides, fn ride ->
        volunteer_requests = Rides.list_volunteer_requests_for_ride(ride.id)
        conversation = Carlosassist.Messages.get_conversation_by_ride(ride.id)

        ride
        |> Map.put(:volunteer_requests, volunteer_requests)
        |> Map.put(:conversation, conversation)
      end)

    assign(socket, :rides, rides_with_requests)
  end

  # Private UI component functions
  defp new_ride_form(assigns) do
    ~H"""
    <div class="sheet">
      <div class="modal-head">
        <div>
          <p class="kicker mb-1">New ride</p>
          <h1 class="page-title">Ask for a ride</h1>
        </div>
        <button phx-click="hide_form" class="btn-icon" aria-label="Close without saving">
          <.icon name="hero-x-mark" class="size-7" />
        </button>
      </div>

      <.wizard_step_indicator step={@wizard_step} />

      <div class="mx-auto mt-8 max-w-2xl">
        <%= case @wizard_step do %>
          <% 1 -> %>
            <.wizard_step_1 wizard_data={@wizard_data} />
          <% 2 -> %>
            <.wizard_step_2 wizard_data={@wizard_data} />
          <% 3 -> %>
            <.wizard_step_3 wizard_data={@wizard_data} />
          <% 4 -> %>
            <.wizard_step_4 wizard_data={@wizard_data} form={@form} />
        <% end %>
      </div>
    </div>
    """
  end

  defp wizard_step_indicator(assigns) do
    ~H"""
    <div>
      <ol class="steps" aria-hidden="true">
        <li :for={n <- 1..4}>
          <span class={[
            "step-dot",
            n < @step && "step-dot-done",
            n == @step && "step-dot-current"
          ]}>
            {n}
          </span>
        </li>
      </ol>
      <p class="kicker text-center">Step {@step} of 4</p>
    </div>
    """
  end

  defp wizard_step_1(assigns) do
    ~H"""
    <h2 class="section-title text-center">Where should we pick you up?</h2>
    <.divider />

    <form phx-submit="next_step">
      <input type="hidden" name="step_data[step]" value="1" />

      <div class="field">
        <label for="pickup-name-input" class="field-label">Name of the place</label>
        <input
          type="text"
          id="pickup-name-input"
          name="step_data[pickup_name]"
          value={Map.get(@wizard_data, "pickup_name", "")}
          placeholder="Home"
          class="field-input"
          required
        />
        <p class="field-help">A short name, such as Home or St. Mary's Church.</p>
      </div>

      <div class="field relative z-10">
        <label for="pickup-address-input" class="field-label">Full address</label>
        <div class="relative">
          <input
            type="text"
            name="step_data[pickup_address]"
            value={Map.get(@wizard_data, "pickup_address", "")}
            placeholder="123 Main Street, City, State 12345"
            class="field-input location-search"
            id="pickup-address-input"
            phx-hook="LocationSearch"
            data-location-type="pickup"
            required
          />
        </div>
      </div>

      <div class="notice mb-8">
        <.icon name="hero-lock-closed" />
        <p>Only the driver you choose sees your full address.</p>
      </div>

      <button type="submit" class="btn btn-gold btn-block">
        Continue <.icon name="hero-arrow-right" class="size-6" />
      </button>
    </form>
    """
  end

  defp wizard_step_2(assigns) do
    ~H"""
    <h2 class="section-title text-center">Where do you need to go?</h2>
    <.divider />

    <form phx-submit="next_step">
      <input type="hidden" name="step_data[step]" value="2" />

      <div class="field">
        <label for="destination-name-input" class="field-label">Name of the place</label>
        <input
          type="text"
          id="destination-name-input"
          name="step_data[destination_name]"
          value={Map.get(@wizard_data, "destination_name", "")}
          placeholder="Doctor's office"
          class="field-input"
          required
        />
        <p class="field-help">A short name, such as Church, Hospital or Grocery store.</p>
      </div>

      <div class="field relative z-10 mb-8">
        <label for="destination-address-input" class="field-label">Full address</label>
        <div class="relative">
          <input
            type="text"
            name="step_data[destination_address]"
            value={Map.get(@wizard_data, "destination_address", "")}
            placeholder="456 Oak Avenue, City, State 12345"
            class="field-input location-search"
            id="destination-address-input"
            phx-hook="LocationSearch"
            data-location-type="destination"
            required
          />
        </div>
      </div>

      <.wizard_buttons />
    </form>
    """
  end

  defp wizard_step_3(assigns) do
    ~H"""
    <h2 class="section-title text-center">When do you need the ride?</h2>
    <.divider />

    <form phx-submit="next_step">
      <input type="hidden" name="step_data[step]" value="3" />

      <div class="field">
        <label for="ride-date-input" class="field-label">Day and time</label>
        <input
          type="datetime-local"
          id="ride-date-input"
          name="step_data[ride_date]"
          value={Map.get(@wizard_data, "ride_date", "")}
          class="field-input"
          required
        />
        <p class="field-help">If you can, ask at least 2 hours before the ride.</p>
      </div>

      <div class="field mb-8">
        <label for="ride-description-input" class="field-label">
          Anything your driver should know (you can leave this empty)
        </label>
        <textarea
          id="ride-description-input"
          name="step_data[description]"
          placeholder="I use a walker. My appointment is at 2 PM."
          class="field-input"
          rows="4"
        >{Map.get(@wizard_data, "description", "")}</textarea>
      </div>

      <.wizard_buttons />
    </form>
    """
  end

  defp wizard_buttons(assigns) do
    ~H"""
    <div class="flex flex-col-reverse gap-3 sm:flex-row">
      <button type="button" phx-click="prev_step" class="btn btn-outline sm:flex-1">
        <.icon name="hero-arrow-left" class="size-6" /> Back
      </button>
      <button type="submit" class="btn btn-gold sm:flex-1">
        Continue <.icon name="hero-arrow-right" class="size-6" />
      </button>
    </div>
    """
  end

  defp wizard_step_4(assigns) do
    ~H"""
    <h2 class="section-title text-center">Check your ride request</h2>
    <.divider />

    <div class="inset mb-8">
      <div class="data-grid">
        <.datum label="Pickup" icon="hero-map-pin">
          {Map.get(@wizard_data, "pickup_name", "")}
          <:note>{Map.get(@wizard_data, "pickup_address", "")}</:note>
        </.datum>

        <.datum label="Going to" icon="hero-flag">
          {Map.get(@wizard_data, "destination_name", "")}
          <:note>{Map.get(@wizard_data, "destination_address", "")}</:note>
        </.datum>

        <.datum label="Day and time" icon="hero-clock" class="data-span">
          {format_datetime(Map.get(@wizard_data, "ride_date", ""))}
        </.datum>

        <div :if={Map.get(@wizard_data, "description", "") != ""} class="data-span">
          <p class="data-label"><.icon name="hero-document-text" class="size-5" /> Your note</p>
          <p class="quote mt-1">{Map.get(@wizard_data, "description", "")}</p>
        </div>
      </div>
    </div>

    <.form for={@form} phx-submit="save">
      <!-- Include wizard data as hidden inputs -->
      <input type="hidden" name="ride[pickup_name]" value={Map.get(@wizard_data, "pickup_name", "")} />
      <input
        type="hidden"
        name="ride[pickup_address]"
        value={Map.get(@wizard_data, "pickup_address", "")}
      />
      <input type="hidden" name="ride[pickup_lat]" value={Map.get(@wizard_data, "pickup_lat", "")} />
      <input type="hidden" name="ride[pickup_long]" value={Map.get(@wizard_data, "pickup_long", "")} />
      <input
        type="hidden"
        name="ride[destination_name]"
        value={Map.get(@wizard_data, "destination_name", "")}
      />
      <input
        type="hidden"
        name="ride[destination_address]"
        value={Map.get(@wizard_data, "destination_address", "")}
      />
      <input
        type="hidden"
        name="ride[destination_lat]"
        value={Map.get(@wizard_data, "destination_lat", "")}
      />
      <input
        type="hidden"
        name="ride[destination_long]"
        value={Map.get(@wizard_data, "destination_long", "")}
      />
      <input type="hidden" name="ride[ride_date]" value={Map.get(@wizard_data, "ride_date", "")} />
      <input type="hidden" name="ride[description]" value={Map.get(@wizard_data, "description", "")} />

      <div class="flex flex-col-reverse gap-3 sm:flex-row">
        <button type="button" phx-click="prev_step" class="btn btn-outline sm:flex-1">
          <.icon name="hero-arrow-left" class="size-6" /> Back to change it
        </button>
        <button type="submit" class="btn btn-gold sm:flex-1">
          <.icon name="hero-check" class="size-6" /> Send my ride request
        </button>
      </div>
    </.form>
    """
  end

  defp rides_list(assigns) do
    grouped_rides = Enum.group_by(assigns.rides, & &1.status)

    groups =
      for {status, title} <- [
            {"pending", "Waiting for a driver"},
            {"confirmed", "Driver chosen"},
            {"completed", "Finished rides"},
            {"cancelled", "Cancelled rides"}
          ],
          rides = Map.get(grouped_rides, status, []),
          rides != [] do
        %{status: status, title: title, rides: rides}
      end

    assigns = assign(assigns, :groups, groups)

    ~H"""
    <div :if={@rides == []} class="sheet text-center">
      <h2 class="section-title">You have no rides yet</h2>
      <.divider />
      <p class="muted mb-8">When you ask for a ride, it is listed here.</p>
      <button phx-click="show_form" class="btn btn-outline">
        <.icon name="hero-plus" class="size-6" /> Ask for your first ride
      </button>
    </div>

    <div :if={@rides != []} class="grid gap-10">
      <section :for={group <- @groups} aria-labelledby={"rides-#{group.status}"}>
        <h2 id={"rides-#{group.status}"} class="section-title mb-4">
          {group.title} <span class="muted">({length(group.rides)})</span>
        </h2>
        <div class="grid gap-5">
          <.compact_ride_card :for={ride <- group.rides} ride={ride} />
        </div>
      </section>
    </div>
    """
  end

  defp compact_ride_card(assigns) do
    assigns = assign(assigns, :offers, length(assigns.ride.volunteer_requests || []))

    ~H"""
    <article class="sheet">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p class="kicker mb-1">{format_ride_date(@ride.ride_date)}</p>
          <h3 class="card-title">{@ride.pickup_name} to {@ride.destination_name}</h3>
        </div>
        <span class={["badge self-start", status_badge_class(@ride.status)]}>
          {format_status(@ride.status)}
        </span>
      </div>

      <p :if={@ride.description && @ride.description != ""} class="quote mt-4">
        {@ride.description}
      </p>
      
    <!-- Offers on a pending ride -->
      <div :if={@ride.status == "pending" && @offers > 0} class="notice notice-positive mt-5">
        <.icon name="hero-hand-raised" />
        <p>
          <strong>
            {if @offers == 1,
              do: "1 driver has offered to take you.",
              else: "#{@offers} drivers have offered to take you."}
          </strong>
          Look at each one and choose your driver.
        </p>
      </div>
      <p :if={@ride.status == "pending" && @offers == 0} class="muted mt-5">
        No driver has offered yet. When one does, you will see it here.
      </p>
      
    <!-- The driver of a confirmed ride -->
      <div :if={@ride.status == "confirmed" && @ride.volunteer} class="mt-5 flex items-center gap-4">
        <.avatar src={@ride.volunteer.profile_pic_location} alt="Your driver" size="md" />
        <div class="min-w-0">
          <p class="data-label">Your driver</p>
          <p class="data-value">{@ride.volunteer.email}</p>
        </div>
      </div>

      <hr class="sheet-rule" />

      <div class="btn-row">
        <button
          :if={@ride.status == "pending" && @offers > 0}
          phx-click="show_ride_details"
          phx-value-ride_id={@ride.id}
          class="btn btn-gold"
        >
          Choose your driver
        </button>
        <.link
          :if={@ride.status == "confirmed" && @ride.conversation}
          navigate={~p"/dashboard/chat/#{@ride.conversation.id}"}
          class="btn btn-gold"
        >
          <.icon name="hero-chat-bubble-left-right" class="size-6" /> Message your driver
        </.link>
        <button
          :if={!(@ride.status == "pending" && @offers > 0)}
          phx-click="show_ride_details"
          phx-value-ride_id={@ride.id}
          class="btn btn-outline"
        >
          See the details
        </button>
        <button
          :if={@ride.status == "pending"}
          phx-click="delete"
          phx-value-id={@ride.id}
          data-confirm="Are you sure you want to delete this ride request?"
          class="btn btn-danger sm:ml-auto"
        >
          <.icon name="hero-trash" class="size-6" /> Delete
        </button>
      </div>
    </article>
    """
  end

  defp ride_details_modal(assigns) do
    assigns = assign(assigns, :offers, length(assigns.ride.volunteer_requests || []))

    ~H"""
    <div
      class="modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="ride-details-title"
      phx-key="Escape"
      phx-window-keydown="hide_ride_details"
    >
      <div class="sheet modal-sheet" phx-click-away="hide_ride_details">
        <div class="modal-head">
          <div>
            <p class="kicker mb-1">Ride details</p>
            <h2 id="ride-details-title" class="page-title">
              {@ride.pickup_name} to {@ride.destination_name}
            </h2>
            <span class={["badge mt-3", status_badge_class(@ride.status)]}>
              {format_status(@ride.status)}
            </span>
          </div>
          <button phx-click="hide_ride_details" class="btn-icon" aria-label="Close">
            <.icon name="hero-x-mark" class="size-7" />
          </button>
        </div>

        <div class="data-grid">
          <.datum label="Pickup" icon="hero-map-pin">
            {@ride.pickup_name}
            <:note>{@ride.pickup_address}</:note>
          </.datum>

          <.datum label="Going to" icon="hero-flag">
            {@ride.destination_name}
            <:note>{@ride.destination_address}</:note>
          </.datum>

          <.datum label="Day and time" icon="hero-clock" class="data-span">
            {format_ride_date(@ride.ride_date)}
          </.datum>

          <div :if={@ride.description && @ride.description != ""} class="data-span">
            <p class="data-label"><.icon name="hero-document-text" class="size-5" /> Your note</p>
            <p class="quote mt-1">{@ride.description}</p>
          </div>
        </div>
        
    <!-- The driver of a confirmed ride -->
        <div :if={@ride.status == "confirmed" && @ride.volunteer}>
          <hr class="sheet-rule" />
          <h3 class="section-title mb-4">Your driver</h3>
          <div class="inset">
            <div class="mb-5 flex flex-col gap-4 sm:flex-row sm:items-center">
              <.avatar src={@ride.volunteer.profile_pic_location} alt="Your driver" size="lg" />
              <div class="min-w-0 flex-1">
                <p class="data-value">{@ride.volunteer.email}</p>
                <p class="data-note flex items-center gap-2">
                  <.icon name="hero-phone" class="size-5" />
                  {@ride.volunteer.phone}
                </p>
              </div>
              <.link
                :if={@ride.conversation}
                navigate={~p"/dashboard/chat/#{@ride.conversation.id}"}
                class="btn btn-gold"
              >
                <.icon name="hero-chat-bubble-left-right" class="size-6" /> Message your driver
              </.link>
            </div>
            <.volunteer_details volunteer={@ride.volunteer} />
          </div>
        </div>
        
    <!-- Offers on a pending ride -->
        <div :if={@ride.status == "pending"}>
          <hr class="sheet-rule" />
          <h3 class="section-title mb-4">
            {if @offers == 0, do: "Drivers", else: "Drivers who have offered (#{@offers})"}
          </h3>
          <.volunteer_browser
            requests={@ride.volunteer_requests || []}
            current_index={Map.get(@volunteer_indices, @ride.id, 0)}
            ride_id={@ride.id}
          />
        </div>

        <hr class="sheet-rule" />

        <div class="btn-row btn-row-between">
          <button
            :if={@ride.status == "confirmed"}
            phx-click="complete_ride"
            phx-value-ride_id={@ride.id}
            data-confirm="Mark this ride as completed?"
            class="btn btn-outline"
          >
            <.icon name="hero-check" class="size-6" /> The ride is done
          </button>
          <button
            :if={@ride.status == "confirmed"}
            phx-click="cancel_ride"
            phx-value-ride_id={@ride.id}
            data-confirm="Cancel this ride? Your volunteer will see it as cancelled."
            class="btn btn-danger"
          >
            <.icon name="hero-x-circle" class="size-6" /> Cancel this ride
          </button>
          <button
            :if={@ride.status == "pending"}
            phx-click="delete"
            phx-value-id={@ride.id}
            data-confirm="Are you sure you want to delete this ride request?"
            class="btn btn-danger"
          >
            <.icon name="hero-trash" class="size-6" /> Delete this request
          </button>
          <button phx-click="hide_ride_details" class="btn btn-outline sm:ml-auto">
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_browser(assigns) do
    ~H"""
    <p :if={@requests == []} class="muted">
      No driver has offered yet. When one does, you will see it here.
    </p>
    <div :if={@requests != []}>
      <% current_request = Enum.at(@requests, @current_index) %>

      <div :if={length(@requests) > 1} class="mb-4 flex items-center justify-between gap-3">
        <button
          phx-click="previous_volunteer"
          phx-value-ride_id={@ride_id}
          class="btn btn-outline"
          aria-label="Previous driver"
        >
          <.icon name="hero-chevron-left" class="size-6" />
          <span class="hidden sm:inline">Previous</span>
        </button>
        <span class="badge">Driver {@current_index + 1} of {length(@requests)}</span>
        <button
          phx-click="next_volunteer"
          phx-value-ride_id={@ride_id}
          class="btn btn-outline"
          aria-label="Next driver"
        >
          <span class="hidden sm:inline">Next</span>
          <.icon name="hero-chevron-right" class="size-6" />
        </button>
      </div>

      <div class="inset">
        <div class="mb-5 flex items-center gap-4">
          <.avatar
            src={current_request.volunteer_user.profile_pic_location}
            alt="Photo of this driver"
            size="xl"
          />
          <div class="min-w-0">
            <p class="data-value">{current_request.volunteer_user.email}</p>
            <p class="data-note flex items-center gap-2">
              <.icon name="hero-phone" class="size-5" />
              {current_request.volunteer_user.phone}
            </p>
          </div>
        </div>

        <.volunteer_details volunteer={current_request.volunteer_user} />

        <div :if={current_request.message} class="mt-5">
          <p class="data-label">
            <.icon name="hero-chat-bubble-bottom-center-text" class="size-5" />
            Message from this driver
          </p>
          <p class="quote mt-1">"{current_request.message}"</p>
        </div>

        <hr class="sheet-rule" />

        <div class="flex flex-col gap-3 sm:flex-row-reverse">
          <button
            phx-click="accept_volunteer"
            phx-value-request_id={current_request.id}
            phx-value-ride_id={@ride_id}
            class="btn btn-gold sm:flex-1"
            data-confirm="Accept this volunteer? This will confirm your ride and other volunteers will be notified."
          >
            <.icon name="hero-check" class="size-6" /> Choose this driver
          </button>
          <button
            phx-click="reject_volunteer"
            phx-value-request_id={current_request.id}
            class="btn btn-danger sm:flex-1"
          >
            No, thank you
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_details(assigns) do
    ~H"""
    <div class="data-grid">
      <.datum label="License plate" icon="hero-identification">
        {@volunteer.volunteer_license_plate || "Not given"}
      </.datum>
      <.datum label="Car" icon="hero-truck">
        {@volunteer.volunteer_car || "Not given"}
      </.datum>
      <div :if={@volunteer.volunteer_bio} class="data-span">
        <p class="data-label"><.icon name="hero-user" class="size-5" /> About this driver</p>
        <p class="mt-1">{@volunteer.volunteer_bio}</p>
      </div>
    </div>
    """
  end

  # Helper functions
  defp status_badge_class("pending"), do: "badge-caution"
  defp status_badge_class("confirmed"), do: "badge-positive"
  defp status_badge_class("completed"), do: "badge-notice"
  defp status_badge_class("cancelled"), do: "badge-danger"
  defp status_badge_class(_), do: nil

  defp format_status("pending"), do: "Waiting for a driver"
  defp format_status("confirmed"), do: "Driver chosen"
  defp format_status("completed"), do: "Finished"
  defp format_status("cancelled"), do: "Cancelled"
  defp format_status(status), do: String.capitalize(status)

  defp format_ride_date(datetime), do: Calendar.strftime(datetime, "%A, %B %-d at %-I:%M %p")

  defp format_datetime(""), do: ""

  defp format_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string <> ":00Z") do
      {:ok, datetime, _} ->
        format_ride_date(datetime)

      _ ->
        datetime_string
    end
  end

  defp format_datetime(datetime), do: to_string(datetime)
end
