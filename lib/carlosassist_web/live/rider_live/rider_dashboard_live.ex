defmodule CarlosassistWeb.RiderDashboardLive do
  @moduledoc """
  Rider home (`/dashboard/rider`): 4-step ride-request wizard (state in
  `:wizard_data`, submitted as hidden inputs at step 4) plus the rider's rides
  grouped by status, with volunteer-offer accept/reject. Not PubSub-subscribed —
  new offers show up on refresh. Template: rider_dashboard_live.html.heex;
  wizard/card markup lives in function components below.
  """
  use CarlosassistWeb, :live_view

  alias Carlosassist.Rides
  alias Carlosassist.Rides.Ride
  alias Carlosassist.Accounts.User

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
         |> put_flash(
           :info,
           "Your ride request is posted. We'll show you volunteers as they offer to help."
         )
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
         |> put_flash(:info, "Your ride request has been removed.")
         |> assign(:rides, rides)
         |> assign(:show_ride_details, false)
         |> assign(:selected_ride, nil)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "We couldn't remove that ride. Please try again.")}
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
         |> put_flash(:info, "Wonderful — your ride is confirmed! You can now message your driver.")
         |> load_rides()}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "We couldn't confirm that volunteer. Please try again.")}
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
         |> put_flash(:info, "No problem — we'll let that volunteer know.")
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Something went wrong. Please try again.")}
    end
  end

  def handle_event("complete_ride", %{"ride_id" => ride_id}, socket) do
    case Rides.complete_ride(String.to_integer(ride_id), socket.assigns.current_scope) do
      {:ok, _ride} ->
        {:noreply,
         socket
         |> put_flash(:info, "Glad it went well! The ride is marked as completed.")
         |> assign(:show_ride_details, false)
         |> assign(:selected_ride, nil)
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "We couldn't complete this ride. Please try again.")}
    end
  end

  def handle_event("cancel_ride", %{"ride_id" => ride_id}, socket) do
    case Rides.cancel_ride(String.to_integer(ride_id), socket.assigns.current_scope) do
      {:ok, _ride} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your ride has been cancelled. Your volunteer will be told.")
         |> assign(:show_ride_details, false)
         |> assign(:selected_ride, nil)
         |> load_rides()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "We couldn't cancel this ride. Please try again.")}
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
    <div class="parish-card mb-8 max-w-3xl mx-auto relative">
      <div class="p-6 sm:p-10">
        <div class="flex justify-between items-start gap-4 mb-6">
          <h2 class="text-2xl sm:text-3xl text-base-content">Ask for a ride</h2>
          <button phx-click="hide_form" class="btn btn-ghost">
            <.icon name="hero-x-mark" class="w-5 h-5" /> Cancel
          </button>
        </div>

        <.wizard_step_indicator step={@wizard_step} />

        <div class="mt-8">
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
    </div>
    """
  end

  defp wizard_step_indicator(assigns) do
    assigns =
      assign(
        assigns,
        :step_names,
        ["Starting point", "Destination", "Day and time", "Check and send"]
      )

    ~H"""
    <div>
      <p class="text-center text-lg font-bold text-base-content mb-3">
        Step {@step} of 4: {Enum.at(@step_names, @step - 1)}
      </p>
      <div class="flex justify-center items-center gap-2" aria-hidden="true">
        <div
          :for={n <- 1..4}
          class={"h-3 rounded-full transition-colors " <>
            if(n <= @step, do: "bg-primary w-12", else: "bg-base-300 w-12")}
        >
        </div>
      </div>
    </div>
    """
  end

  defp wizard_step_1(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-map-pin" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-2xl text-base-content mb-2">Where should we pick you up?</h3>
      </div>

      <form phx-submit="next_step" class="space-y-6">
        <input type="hidden" name="step_data[step]" value="1" />

        <div class="space-y-2">
          <label for="pickup-name-input" class="block text-lg font-bold text-base-content">
            What do you call this place?
          </label>
          <input
            id="pickup-name-input"
            type="text"
            name="step_data[pickup_name]"
            value={Map.get(@wizard_data, "pickup_name", "")}
            placeholder="For example: Home"
            class="input input-bordered w-full text-lg"
            required
          />
        </div>

        <div class="space-y-2 relative z-10">
          <label for="pickup-address-input" class="block text-lg font-bold text-base-content">
            The full address
          </label>
          <div class="relative mapbox-geocoder-wrapper">
            <input
              type="text"
              name="step_data[pickup_address]"
              value={Map.get(@wizard_data, "pickup_address", "")}
              placeholder="123 Main Street, City"
              class="input input-bordered w-full text-lg location-search"
              id="pickup-address-input"
              phx-hook="LocationSearch"
              data-location-type="pickup"
              required
            />
          </div>
          <div class="flex items-start gap-2 text-base text-base-content/75 bg-base-200 p-3 rounded-lg">
            <.icon name="hero-lock-closed" class="w-5 h-5 mt-0.5 shrink-0 text-accent" />
            <span>
              Your exact address stays private. Volunteers only see it after you choose them.
            </span>
          </div>
        </div>

        <div class="pt-4">
          <button type="submit" class="btn btn-primary btn-lg w-full">
            Next <.icon name="hero-arrow-right" class="w-5 h-5" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp wizard_step_2(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-flag" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-2xl text-base-content mb-2">Where do you need to go?</h3>
      </div>

      <form phx-submit="next_step" class="space-y-6">
        <input type="hidden" name="step_data[step]" value="2" />

        <div class="space-y-2">
          <label for="destination-name-input" class="block text-lg font-bold text-base-content">
            What do you call this place?
          </label>
          <input
            id="destination-name-input"
            type="text"
            name="step_data[destination_name]"
            value={Map.get(@wizard_data, "destination_name", "")}
            placeholder="For example: St. Mary's Church, the doctor's office"
            class="input input-bordered w-full text-lg"
            required
          />
        </div>

        <div class="space-y-2 relative z-10">
          <label for="destination-address-input" class="block text-lg font-bold text-base-content">
            The full address
          </label>
          <div class="relative mapbox-geocoder-wrapper">
            <input
              type="text"
              name="step_data[destination_address]"
              value={Map.get(@wizard_data, "destination_address", "")}
              placeholder="456 Oak Avenue, City"
              class="input input-bordered w-full text-lg location-search"
              id="destination-address-input"
              phx-hook="LocationSearch"
              data-location-type="destination"
              required
            />
          </div>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 pt-4">
          <button type="button" phx-click="prev_step" class="btn btn-outline btn-lg flex-1">
            <.icon name="hero-arrow-left" class="w-5 h-5" /> Go back
          </button>
          <button type="submit" class="btn btn-primary btn-lg flex-1">
            Next <.icon name="hero-arrow-right" class="w-5 h-5" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp wizard_step_3(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-clock" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-2xl text-base-content mb-2">When do you need the ride?</h3>
      </div>

      <form phx-submit="next_step" class="space-y-6">
        <input type="hidden" name="step_data[step]" value="3" />

        <div class="space-y-2">
          <label for="ride-date-input" class="block text-lg font-bold text-base-content">
            Day and time
          </label>
          <input
            id="ride-date-input"
            type="datetime-local"
            name="step_data[ride_date]"
            value={Map.get(@wizard_data, "ride_date", "")}
            class="input input-bordered w-full text-lg"
            required
          />
          <p class="text-base text-base-content/75">
            The earlier you ask, the easier it is for a volunteer to plan for you.
          </p>
        </div>

        <div class="space-y-2">
          <label for="ride-notes-input" class="block text-lg font-bold text-base-content">
            Anything your driver should know? <span class="font-normal text-base-content/60">(optional)</span>
          </label>
          <textarea
            id="ride-notes-input"
            name="step_data[description]"
            placeholder="For example: I use a walker. My appointment is at 2 o'clock. I'll have a few grocery bags."
            class="textarea textarea-bordered w-full h-32 text-lg"
            rows="4"
          >{Map.get(@wizard_data, "description", "")}</textarea>
        </div>

        <div class="flex flex-col sm:flex-row gap-3 pt-4">
          <button type="button" phx-click="prev_step" class="btn btn-outline btn-lg flex-1">
            <.icon name="hero-arrow-left" class="w-5 h-5" /> Go back
          </button>
          <button type="submit" class="btn btn-primary btn-lg flex-1">
            Next <.icon name="hero-arrow-right" class="w-5 h-5" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp wizard_step_4(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-check-circle" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-2xl text-base-content mb-2">Does everything look right?</h3>
        <p class="text-lg text-base-content/75">You can go back and change anything.</p>
      </div>

      <div class="bg-base-200 border-2 border-base-300 p-6 rounded-xl space-y-5">
        <div>
          <p class="text-base font-bold text-base-content/70 flex items-center gap-2 mb-1">
            <.icon name="hero-map-pin" class="w-5 h-5" /> Picking you up at
          </p>
          <p class="text-lg font-bold text-base-content">
            {Map.get(@wizard_data, "pickup_name", "")}
          </p>
          <p class="text-base text-base-content/75">{Map.get(@wizard_data, "pickup_address", "")}</p>
        </div>

        <div>
          <p class="text-base font-bold text-base-content/70 flex items-center gap-2 mb-1">
            <.icon name="hero-flag" class="w-5 h-5" /> Taking you to
          </p>
          <p class="text-lg font-bold text-base-content">
            {Map.get(@wizard_data, "destination_name", "")}
          </p>
          <p class="text-base text-base-content/75">
            {Map.get(@wizard_data, "destination_address", "")}
          </p>
        </div>

        <div>
          <p class="text-base font-bold text-base-content/70 flex items-center gap-2 mb-1">
            <.icon name="hero-clock" class="w-5 h-5" /> On
          </p>
          <p class="text-lg font-bold text-base-content">
            {format_datetime(Map.get(@wizard_data, "ride_date", ""))}
          </p>
        </div>

        <div :if={Map.get(@wizard_data, "description", "") != ""}>
          <p class="text-base font-bold text-base-content/70 flex items-center gap-2 mb-1">
            <.icon name="hero-document-text" class="w-5 h-5" /> Notes for your driver
          </p>
          <p class="text-base text-base-content">
            {Map.get(@wizard_data, "description", "")}
          </p>
        </div>
      </div>

      <.form for={@form} phx-submit="save">
        <!-- Include wizard data as hidden inputs -->
        <input
          type="hidden"
          name="ride[pickup_name]"
          value={Map.get(@wizard_data, "pickup_name", "")}
        />
        <input
          type="hidden"
          name="ride[pickup_address]"
          value={Map.get(@wizard_data, "pickup_address", "")}
        />
        <input type="hidden" name="ride[pickup_lat]" value={Map.get(@wizard_data, "pickup_lat", "")} />
        <input
          type="hidden"
          name="ride[pickup_long]"
          value={Map.get(@wizard_data, "pickup_long", "")}
        />
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
        <input
          type="hidden"
          name="ride[description]"
          value={Map.get(@wizard_data, "description", "")}
        />

        <div class="flex flex-col sm:flex-row gap-3 pt-6">
          <button type="button" phx-click="prev_step" class="btn btn-outline btn-lg flex-1">
            <.icon name="hero-arrow-left" class="w-5 h-5" /> Go back
          </button>
          <button type="submit" class="btn btn-primary btn-lg flex-1">
            <.icon name="hero-check" class="w-5 h-5" /> Ask for this ride
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp rides_list(assigns) do
    # Group rides by status
    grouped_rides = Enum.group_by(assigns.rides, & &1.status)
    pending_rides = Map.get(grouped_rides, "pending", [])
    confirmed_rides = Map.get(grouped_rides, "confirmed", [])
    completed_rides = Map.get(grouped_rides, "completed", [])
    cancelled_rides = Map.get(grouped_rides, "cancelled", [])

    assigns = assign(assigns, :pending_rides, pending_rides)
    assigns = assign(assigns, :confirmed_rides, confirmed_rides)
    assigns = assign(assigns, :completed_rides, completed_rides)
    assigns = assign(assigns, :cancelled_rides, cancelled_rides)

    ~H"""
    <div :if={@rides == []} class="text-center py-14">
      <div class="w-20 h-20 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-6">
        <.icon name="hero-truck" class="w-10 h-10 text-primary" />
      </div>
      <h3 class="text-2xl text-base-content mb-2">You haven't asked for any rides yet</h3>
      <p class="text-lg text-base-content/75 mb-8 max-w-md mx-auto">
        When you need to get somewhere, press the button below and we'll ask
        your neighbors for help.
      </p>
      <button phx-click="show_form" class="btn btn-primary btn-xl px-8">
        <.icon name="hero-plus" class="w-6 h-6" /> Ask for my first ride
      </button>
    </div>

    <div :if={@rides != []} class="space-y-10">
      <!-- Confirmed rides first: they're what's happening next -->
      <div :if={@confirmed_rides != []}>
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-check-circle" class="w-6 h-6 text-success" />
          <h3 class="text-xl font-bold text-base-content">Your confirmed rides</h3>
        </div>
        <div class="space-y-4">
          <.compact_ride_card
            :for={ride <- @confirmed_rides}
            ride={ride}
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>

      <div :if={@pending_rides != []}>
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-clock" class="w-6 h-6 text-warning" />
          <h3 class="text-xl font-bold text-base-content">Waiting for a volunteer</h3>
        </div>
        <div class="space-y-4">
          <.compact_ride_card
            :for={ride <- @pending_rides}
            ride={ride}
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>

      <div :if={@completed_rides != []}>
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-check-badge" class="w-6 h-6 text-primary" />
          <h3 class="text-xl font-bold text-base-content">Past rides</h3>
        </div>
        <div class="space-y-4">
          <.compact_ride_card
            :for={ride <- @completed_rides}
            ride={ride}
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>

      <div :if={@cancelled_rides != []}>
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-x-circle" class="w-6 h-6 text-error" />
          <h3 class="text-xl font-bold text-base-content">Cancelled rides</h3>
        </div>
        <div class="space-y-4">
          <.compact_ride_card
            :for={ride <- @cancelled_rides}
            ride={ride}
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>
    </div>
    """
  end

  defp compact_ride_card(assigns) do
    ~H"""
    <div class="parish-card">
      <div class="p-5">
        <div class="flex flex-col sm:flex-row sm:items-start gap-4">
          <button
            class="flex-1 text-left cursor-pointer rounded-lg hover:bg-base-200/60 -m-2 p-2"
            phx-click="show_ride_details"
            phx-value-ride_id={@ride.id}
          >
            <div class="flex flex-wrap items-center gap-2 mb-2">
              <span class={"inline-flex items-center px-3 py-1 rounded-full text-base font-bold " <> status_badge_class(@ride.status)}>
                {format_status(@ride.status)}
              </span>
            </div>
            <p class="text-lg font-bold text-base-content mb-1">
              {@ride.pickup_name}
              <.icon name="hero-arrow-right" class="w-4 h-4 inline mx-1 text-base-content/50" />
              {@ride.destination_name}
            </p>
            <p class="text-base text-base-content/75 flex items-center gap-2">
              <.icon name="hero-calendar" class="w-5 h-5" />
              {Calendar.strftime(@ride.ride_date, "%A, %B %d at %I:%M %p")}
            </p>
            <p class="text-base text-primary font-bold mt-2 flex items-center gap-1">
              See details <.icon name="hero-chevron-right" class="w-4 h-4" />
            </p>
          </button>

          <div class="flex flex-col gap-2 sm:w-44 shrink-0">
            <.link
              :if={@ride.status == "confirmed" && @ride.conversation}
              navigate={~p"/dashboard/chat/#{@ride.conversation.id}"}
              class="btn btn-primary"
            >
              <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" /> Message driver
            </.link>

            <button
              :if={@ride.status == "confirmed"}
              phx-click="complete_ride"
              phx-value-ride_id={@ride.id}
              data-confirm="Did this ride happen? Press OK to mark it as completed."
              class="btn btn-outline"
            >
              <.icon name="hero-check" class="w-5 h-5" /> Ride is done
            </button>
            <button
              :if={@ride.status == "confirmed"}
              phx-click="cancel_ride"
              phx-value-ride_id={@ride.id}
              data-confirm="Cancel this ride? Your volunteer will be told."
              class="btn btn-ghost text-error"
            >
              <.icon name="hero-x-circle" class="w-5 h-5" /> Cancel ride
            </button>

            <button
              :if={@ride.status == "pending"}
              phx-click="delete"
              phx-value-id={@ride.id}
              data-confirm="Remove this ride request? Volunteers will no longer see it."
              class="btn btn-ghost text-error"
            >
              <.icon name="hero-trash" class="w-5 h-5" /> Remove request
            </button>
          </div>
        </div>

        <div
          :if={@ride.description && @ride.description != ""}
          class="mt-4 pt-4 border-t border-base-300"
        >
          <p class="text-base text-base-content/80 bg-base-200 p-3 rounded-lg">
            <span class="font-bold">Your note:</span> {@ride.description}
          </p>
        </div>

        <!-- Volunteers offering to help, shown right on the card -->
        <div
          :if={
            @ride.status == "pending" && @ride.volunteer_requests &&
              length(@ride.volunteer_requests) > 0
          }
          class="mt-5 pt-5 border-t-2 border-primary/20"
        >
          <p class="text-lg font-bold text-primary mb-3 flex items-center gap-2">
            <.icon name="hero-hand-raised" class="w-6 h-6" />
            {volunteer_offer_headline(length(@ride.volunteer_requests))}
          </p>
          <.volunteer_browser
            requests={@ride.volunteer_requests}
            current_index={Map.get(@volunteer_indices, @ride.id, 0)}
            ride_id={@ride.id}
          />
        </div>

        <div
          :if={@ride.status == "pending" && (@ride.volunteer_requests || []) == []}
          class="mt-4 pt-4 border-t border-base-300"
        >
          <p class="text-base text-base-content/75 flex items-center gap-2">
            <.icon name="hero-clock" class="w-5 h-5 shrink-0" />
            Volunteers can now see your request. We'll show their offers here —
            check back soon.
          </p>
        </div>

        <div
          :if={@ride.status == "confirmed" && @ride.volunteer}
          class="mt-5 pt-5 border-t-2 border-success/30"
        >
          <div class="flex items-center gap-4">
            <.avatar src={@ride.volunteer.profile_pic_location} alt="Your driver's photo" size="lg" />
            <div class="flex-1">
              <p class="text-base font-bold text-success">Your driver</p>
              <p class="text-lg font-bold text-base-content">
                {User.display_name(@ride.volunteer)}
              </p>
              <p class="text-base text-base-content/75">
                {@ride.volunteer.volunteer_car}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp ride_details_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/50 overflow-y-auto h-full w-full z-50"
      phx-key="Escape"
      phx-window-keydown="hide_ride_details"
    >
      <div
        class="relative top-8 mx-auto p-6 sm:p-8 w-full max-w-3xl parish-card m-4"
        phx-click-away="hide_ride_details"
      >
        <!-- Header -->
        <div class="flex justify-between items-start mb-6">
          <div>
            <h2 class="text-2xl sm:text-3xl text-base-content mb-2">
              About this ride
            </h2>
            <span class={"inline-flex items-center px-3 py-1 rounded-full text-base font-bold " <> status_badge_class(@ride.status)}>
              {format_status(@ride.status)}
            </span>
          </div>
          <button phx-click="hide_ride_details" class="btn btn-ghost">
            <.icon name="hero-x-mark" class="w-5 h-5" /> Close
          </button>
        </div>

        <!-- Ride Information -->
        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="space-y-5">
            <div>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-map-pin" class="w-5 h-5" /> Picking you up at
              </h3>
              <p class="text-lg font-bold text-base-content">{@ride.pickup_name}</p>
              <p class="text-base text-base-content/75">{@ride.pickup_address}</p>
            </div>

            <div>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-flag" class="w-5 h-5" /> Taking you to
              </h3>
              <p class="text-lg font-bold text-base-content">{@ride.destination_name}</p>
              <p class="text-base text-base-content/75">{@ride.destination_address}</p>
            </div>
          </div>

          <div class="space-y-5">
            <div>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-clock" class="w-5 h-5" /> On
              </h3>
              <p class="text-lg font-bold text-base-content">
                {Calendar.strftime(@ride.ride_date, "%A, %B %d, %Y")}
              </p>
              <p class="text-base text-base-content/75">
                at {Calendar.strftime(@ride.ride_date, "%I:%M %p")}
              </p>
            </div>

            <div :if={@ride.description && @ride.description != ""}>
              <h3 class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
                <.icon name="hero-document-text" class="w-5 h-5" /> Your note
              </h3>
              <p class="text-base text-base-content bg-base-200 p-3 rounded-lg">
                {@ride.description}
              </p>
            </div>
          </div>
        </div>

        <!-- Status-specific sections -->
        <div class="space-y-6">
          <!-- Confirmed Volunteer (for confirmed rides) -->
          <div :if={@ride.status == "confirmed" && @ride.volunteer} class="border-t-2 border-base-300 pt-6">
            <h3 class="text-xl font-bold mb-4 text-success flex items-center gap-2">
              <.icon name="hero-check-circle" class="w-6 h-6" /> Your driver
            </h3>
            <div class="bg-success/10 border-2 border-success/20 p-6 rounded-xl">
              <div class="flex flex-col sm:flex-row sm:items-start gap-4 mb-4">
                <.avatar src={@ride.volunteer.profile_pic_location} alt="Your driver's photo" size="xl" />
                <div class="flex-1">
                  <p class="text-xl font-bold text-base-content mb-1">
                    {User.display_name(@ride.volunteer)}
                  </p>
                  <p class="text-base text-base-content/75 flex items-center gap-2">
                    <.icon name="hero-phone" class="w-5 h-5" />
                    {@ride.volunteer.phone}
                  </p>
                </div>
                <.link
                  :if={@ride.conversation}
                  navigate={~p"/dashboard/chat/#{@ride.conversation.id}"}
                  class="btn btn-primary"
                >
                  <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" /> Message driver
                </.link>
              </div>
              <.volunteer_details volunteer={@ride.volunteer} />
            </div>
          </div>

          <!-- Volunteer Requests (for pending rides) -->
          <div
            :if={
              @ride.status == "pending" && @ride.volunteer_requests &&
                length(@ride.volunteer_requests) > 0
            }
            class="border-t-2 border-base-300 pt-6"
          >
            <h3 class="text-xl font-bold mb-4 text-primary flex items-center gap-2">
              <.icon name="hero-hand-raised" class="w-6 h-6" />
              {volunteer_offer_headline(length(@ride.volunteer_requests))}
            </h3>
            <.volunteer_browser
              requests={@ride.volunteer_requests}
              current_index={Map.get(@volunteer_indices, @ride.id, 0)}
              ride_id={@ride.id}
            />
          </div>
        </div>

        <!-- Actions -->
        <div class="flex flex-col sm:flex-row sm:justify-between gap-3 mt-8 pt-6 border-t-2 border-base-300">
          <div class="flex flex-col sm:flex-row gap-2">
            <button
              :if={@ride.status == "pending"}
              phx-click="delete"
              phx-value-id={@ride.id}
              data-confirm="Remove this ride request? Volunteers will no longer see it."
              class="btn btn-outline btn-error"
            >
              <.icon name="hero-trash" class="w-5 h-5" /> Remove this request
            </button>
            <button
              :if={@ride.status == "confirmed"}
              phx-click="complete_ride"
              phx-value-ride_id={@ride.id}
              data-confirm="Did this ride happen? Press OK to mark it as completed."
              class="btn btn-outline"
            >
              <.icon name="hero-check" class="w-5 h-5" /> The ride is done
            </button>
            <button
              :if={@ride.status == "confirmed"}
              phx-click="cancel_ride"
              phx-value-ride_id={@ride.id}
              data-confirm="Cancel this ride? Your volunteer will be told."
              class="btn btn-outline btn-error"
            >
              <.icon name="hero-x-circle" class="w-5 h-5" /> Cancel this ride
            </button>
          </div>

          <button phx-click="hide_ride_details" class="btn btn-primary">
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_browser(assigns) do
    ~H"""
    <div :if={@requests == []} class="text-center py-8 text-base text-base-content/70">
      No offers yet. Volunteers will see your request and offer to help.
    </div>
    <div :if={@requests != []}>
      <% current_request = Enum.at(@requests, @current_index) %>

      <p :if={length(@requests) > 1} class="text-center text-base font-bold text-base-content/75 mb-4">
        Offer {@current_index + 1} of {length(@requests)}
      </p>

      <!-- Single volunteer card -->
      <div class="bg-primary/5 border-2 border-primary/25 p-5 sm:p-6 rounded-xl">
        <div class="flex items-start gap-4 mb-4">
          <.avatar
            src={current_request.volunteer_user.profile_pic_location}
            alt="Volunteer's photo"
            size="xl"
          />
          <div class="flex-1">
            <p class="text-xl font-bold text-base-content mb-1">
              {User.display_name(current_request.volunteer_user)}
            </p>
            <p class="text-base text-base-content/75">
              would be glad to drive you
            </p>
          </div>
        </div>

        <.volunteer_details volunteer={current_request.volunteer_user} />

        <div :if={current_request.message && current_request.message != ""} class="mt-5">
          <p class="text-base font-bold text-base-content/70 mb-2">
            A note from {User.first_name(current_request.volunteer_user)}:
          </p>
          <p class="text-lg bg-base-100 p-4 rounded-xl border-2 border-base-300 font-display italic">
            “{current_request.message}”
          </p>
        </div>

        <!-- Decide on this volunteer -->
        <div class="mt-6 pt-5 border-t-2 border-primary/20">
          <div class="flex flex-col sm:flex-row gap-3">
            <button
              phx-click="accept_volunteer"
              phx-value-request_id={current_request.id}
              phx-value-ride_id={@ride_id}
              class="btn btn-primary btn-lg flex-1"
              data-confirm={"Choose #{User.first_name(current_request.volunteer_user)} as your driver? This confirms your ride."}
            >
              <.icon name="hero-check" class="w-6 h-6" />
              Choose {User.first_name(current_request.volunteer_user)}
            </button>
            <button
              phx-click="reject_volunteer"
              phx-value-request_id={current_request.id}
              class="btn btn-outline btn-lg flex-1"
            >
              No, thank you
            </button>
          </div>

          <div :if={length(@requests) > 1} class="flex justify-between items-center mt-4">
            <button
              phx-click="previous_volunteer"
              phx-value-ride_id={@ride_id}
              class="btn btn-ghost"
            >
              <.icon name="hero-chevron-left" class="w-5 h-5" /> See previous offer
            </button>
            <button
              phx-click="next_volunteer"
              phx-value-ride_id={@ride_id}
              class="btn btn-ghost"
            >
              See next offer <.icon name="hero-chevron-right" class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_details(assigns) do
    ~H"""
    <div class="grid sm:grid-cols-2 gap-4">
      <div>
        <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
          <.icon name="hero-truck" class="w-5 h-5" /> Their car
        </p>
        <p class="text-lg font-bold text-base-content">
          {@volunteer.volunteer_car || "Not provided"}
        </p>
      </div>
      <div>
        <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
          <.icon name="hero-identification" class="w-5 h-5" /> License plate
        </p>
        <p class="text-lg font-bold text-base-content">
          {@volunteer.volunteer_license_plate || "Not provided"}
        </p>
      </div>
      <div :if={@volunteer.volunteer_bio} class="sm:col-span-2">
        <p class="text-base font-bold text-base-content/70 mb-1 flex items-center gap-2">
          <.icon name="hero-user" class="w-5 h-5" /> About them
        </p>
        <p class="text-base text-base-content/85 bg-base-100 p-3 rounded-lg border border-base-300">
          {@volunteer.volunteer_bio}
        </p>
      </div>
    </div>
    """
  end

  # Helper functions
  defp volunteer_offer_headline(1), do: "A neighbor has offered to drive you"
  defp volunteer_offer_headline(n), do: "#{n} neighbors have offered to drive you"

  defp status_badge_class("pending"), do: "bg-warning/15 text-warning border-2 border-warning/40"
  defp status_badge_class("confirmed"), do: "bg-success/15 text-success border-2 border-success/40"
  defp status_badge_class("completed"), do: "bg-primary/15 text-primary border-2 border-primary/40"
  defp status_badge_class("cancelled"), do: "bg-error/15 text-error border-2 border-error/40"
  defp status_badge_class(_), do: "bg-neutral/15 text-neutral border-2 border-neutral/40"

  defp format_status("pending"), do: "Waiting for a volunteer"
  defp format_status("confirmed"), do: "Driver confirmed"
  defp format_status("completed"), do: "Completed"
  defp format_status("cancelled"), do: "Cancelled"
  defp format_status(status), do: String.capitalize(status)

  defp format_datetime(""), do: ""

  defp format_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string <> ":00Z") do
      {:ok, datetime, _} ->
        Calendar.strftime(datetime, "%A, %B %d, %Y at %I:%M %p")

      _ ->
        datetime_string
    end
  end

  defp format_datetime(datetime), do: to_string(datetime)
end
