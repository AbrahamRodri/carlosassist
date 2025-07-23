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

  def handle_event("next_volunteer", %{"ride_id" => ride_id}, socket) do
    ride_id = String.to_integer(ride_id)
    current_indices = socket.assigns.volunteer_indices
    current_index = Map.get(current_indices, ride_id, 0)
    
    # Find the ride to get volunteer count
    ride = Enum.find(socket.assigns.rides, &(&1.id == ride_id))
    volunteer_count = if ride && ride.volunteer_requests, do: length(ride.volunteer_requests), else: 0
    
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
    volunteer_count = if ride && ride.volunteer_requests, do: length(ride.volunteer_requests), else: 0
    
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
    <div class="card-modern mb-8 max-w-4xl mx-auto relative">
      <div class="p-8">
        <div class="flex justify-between items-center mb-8">
          <h2 class="text-2xl font-semibold text-base-content">Request a Ride</h2>
          <button phx-click="hide_form" class="btn btn-ghost btn-sm p-2 hover:bg-slate-100 rounded-lg">
            <.icon name="hero-x-mark" class="w-5 h-5 text-base-content/60" />
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
    ~H"""
    <div class="mb-8">
      <div class="flex justify-center items-center space-x-4 mb-4">
        <div class={"flex items-center justify-center w-10 h-10 rounded-full text-sm font-medium border-2 " <>
                   if(@step >= 1, do: "bg-primary border-primary text-primary-content", else: "border-base-300 text-base-content/50")}>
          1
        </div>
        <div class={"h-0.5 w-12 " <> if(@step > 1, do: "bg-primary", else: "bg-base-300")}></div>
        <div class={"flex items-center justify-center w-10 h-10 rounded-full text-sm font-medium border-2 " <>
                   if(@step >= 2, do: "bg-primary border-primary text-primary-content", else: "border-base-300 text-base-content/50")}>
          2
        </div>
        <div class={"h-0.5 w-12 " <> if(@step > 2, do: "bg-primary", else: "bg-base-300")}></div>
        <div class={"flex items-center justify-center w-10 h-10 rounded-full text-sm font-medium border-2 " <>
                   if(@step >= 3, do: "bg-primary border-primary text-primary-content", else: "border-base-300 text-base-content/50")}>
          3
        </div>
        <div class={"h-0.5 w-12 " <> if(@step > 3, do: "bg-primary", else: "bg-base-300")}></div>
        <div class={"flex items-center justify-center w-10 h-10 rounded-full text-sm font-medium border-2 " <>
                   if(@step >= 4, do: "bg-primary border-primary text-primary-content", else: "border-base-300 text-base-content/50")}>
          4
        </div>
      </div>
      <div class="text-center">
        <p class="text-sm font-medium text-base-content mb-1">
          <%= case @step do %>
            <% 1 -> %>
              Pickup Location
            <% 2 -> %>
              Destination
            <% 3 -> %>
              Date & Time
            <% 4 -> %>
              Review & Submit
          <% end %>
        </p>
        <p class="text-xs text-base-content/60">Step {@step} of 4</p>
      </div>
    </div>
    """
  end

  defp wizard_step_1(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-map-pin" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-lg font-semibold text-base-content mb-2">Pickup Location</h3>
        <p class="text-base-content/70">Where should we pick you up?</p>
      </div>

      <form phx-submit="next_step" class="space-y-6">
        <input type="hidden" name="step_data[step]" value="1" />

        <div class="space-y-4">
          <label class="block text-sm font-medium text-base-content/80">Location Name</label>
          <input
            type="text"
            name="step_data[pickup_name]"
            value={Map.get(@wizard_data, "pickup_name", "")}
            placeholder="Home, Office, Doctor's Office..."
            class="input input-bordered w-full"
            required
          />
          <p class="text-xs text-base-content/60">
            A simple name that helps volunteers identify the location
          </p>
        </div>

        <div class="space-y-4 relative z-10">
          <label class="block text-sm font-medium text-base-content/80">Complete Address</label>
          <div class="relative mapbox-geocoder-wrapper">
            <input
              type="text"
              name="step_data[pickup_address]"
              value={Map.get(@wizard_data, "pickup_address", "")}
              placeholder="123 Main Street, City, State 12345"
              class="input input-bordered w-full location-search"
              id="pickup-address-input"
              phx-hook="LocationSearch"
              data-location-type="pickup"
              required
            />
          </div>
          <div class="flex items-start gap-2 text-xs text-base-content/60 bg-base-200 p-3 rounded-lg">
            <.icon name="hero-lock-closed" class="w-4 h-4 mt-0.5 text-base-content/40" />
            <span>
              Your exact address will only be shared with the volunteer after you accept them
            </span>
          </div>
        </div>

        <div class="pt-6">
          <button
            type="submit"
            class="btn btn-primary btn-modern w-full flex items-center justify-center gap-2"
          >
            Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp wizard_step_2(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-flag" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-lg font-semibold text-base-content mb-2">Destination</h3>
        <p class="text-base-content/70">Where do you need to go?</p>
      </div>

      <form phx-submit="next_step" class="space-y-6">
        <input type="hidden" name="step_data[step]" value="2" />

        <div class="space-y-4">
          <label class="block text-sm font-medium text-base-content/80">Location Name</label>
          <input
            type="text"
            name="step_data[destination_name]"
            value={Map.get(@wizard_data, "destination_name", "")}
            placeholder="Hospital, Grocery Store, Church..."
            class="input input-bordered w-full"
            required
          />
        </div>

        <div class="space-y-4 relative z-10">
          <label class="block text-sm font-medium text-base-content/80">Complete Address</label>
          <div class="relative mapbox-geocoder-wrapper">
            <input
              type="text"
              name="step_data[destination_address]"
              value={Map.get(@wizard_data, "destination_address", "")}
              placeholder="456 Oak Avenue, City, State 12345"
              class="input input-bordered w-full location-search"
              id="destination-address-input"
              phx-hook="LocationSearch"
              data-location-type="destination"
              required
            />
          </div>
        </div>

        <div class="flex gap-3 pt-6">
          <button
            type="button"
            phx-click="prev_step"
            class="btn btn-outline btn-modern flex-1 flex items-center justify-center gap-2"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
          </button>
          <button
            type="submit"
            class="btn btn-primary btn-modern flex-1 flex items-center justify-center gap-2"
          >
            Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp wizard_step_3(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-clock" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-lg font-semibold text-base-content mb-2">Date & Time</h3>
        <p class="text-base-content/70">When do you need this ride?</p>
      </div>

      <form phx-submit="next_step" class="space-y-6">
        <input type="hidden" name="step_data[step]" value="3" />

        <div class="space-y-4">
          <label class="block text-sm font-medium text-base-content/80">
            Pick your date and time
          </label>
          <input
            type="datetime-local"
            name="step_data[ride_date]"
            value={Map.get(@wizard_data, "ride_date", "")}
            class="input input-bordered w-full"
            required
          />
          <p class="text-xs text-base-content/60">
            Please give at least 2 hours notice when possible
          </p>
        </div>

        <div class="space-y-4">
          <label class="block text-sm font-medium text-base-content/80">
            Add any special notes (optional)
          </label>
          <textarea
            name="step_data[description]"
            placeholder="I need help with groceries, I use a walker, appointment at 2pm..."
            class="textarea textarea-bordered w-full h-32"
            rows="4"
          >{Map.get(@wizard_data, "description", "")}</textarea>
        </div>

        <div class="flex gap-3 pt-6">
          <button
            type="button"
            phx-click="prev_step"
            class="btn btn-outline btn-modern flex-1 flex items-center justify-center gap-2"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
          </button>
          <button
            type="submit"
            class="btn btn-primary btn-modern flex-1 flex items-center justify-center gap-2"
          >
            Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp wizard_step_4(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <.icon name="hero-check-circle" class="w-8 h-8 text-primary" />
        </div>
        <h3 class="text-lg font-semibold text-base-content mb-2">Review Your Ride Request</h3>
        <p class="text-base-content/70">Please review your details before submitting</p>
      </div>

      <div class="bg-base-200/50 p-6 rounded-lg space-y-6">
        <div class="grid gap-6">
          <div>
            <h4 class="text-sm font-medium mb-2 text-base-content/80 flex items-center gap-2">
              <.icon name="hero-map-pin" class="w-5 h-5" /> Pickup Location
            </h4>
            <p class="text-base font-medium text-base-content">
              {Map.get(@wizard_data, "pickup_name", "")}
            </p>
            <p class="text-base-content/70">{Map.get(@wizard_data, "pickup_address", "")}</p>
          </div>

          <div>
            <h4 class="text-sm font-medium mb-2 text-base-content/80 flex items-center gap-2">
              <.icon name="hero-flag" class="w-5 h-5" /> Destination
            </h4>
            <p class="text-base font-medium text-base-content">
              {Map.get(@wizard_data, "destination_name", "")}
            </p>
            <p class="text-base-content/70">{Map.get(@wizard_data, "destination_address", "")}</p>
          </div>

          <div>
            <h4 class="text-sm font-medium mb-2 text-base-content/80 flex items-center gap-2">
              <.icon name="hero-clock" class="w-5 h-5" /> Date & Time
            </h4>
            <p class="text-base font-medium text-base-content">
              {format_datetime(Map.get(@wizard_data, "ride_date", ""))}
            </p>
          </div>

          <div :if={Map.get(@wizard_data, "description", "") != ""}>
            <h4 class="text-sm font-medium mb-2 text-base-content/80 flex items-center gap-2">
              <.icon name="hero-document-text" class="w-5 h-5" /> Special Notes
            </h4>
            <p class="text-base font-medium text-base-content">
              {Map.get(@wizard_data, "description", "")}
            </p>
          </div>
        </div>
      </div>

      <.form for={@form} phx-submit="save">
        <!-- Include wizard data as hidden inputs -->
        <input type="hidden" name="ride[pickup_name]" value={Map.get(@wizard_data, "pickup_name", "")} />
        <input type="hidden" name="ride[pickup_address]" value={Map.get(@wizard_data, "pickup_address", "")} />
        <input type="hidden" name="ride[pickup_lat]" value={Map.get(@wizard_data, "pickup_lat", "")} />
        <input type="hidden" name="ride[pickup_long]" value={Map.get(@wizard_data, "pickup_long", "")} />
        <input type="hidden" name="ride[destination_name]" value={Map.get(@wizard_data, "destination_name", "")} />
        <input type="hidden" name="ride[destination_address]" value={Map.get(@wizard_data, "destination_address", "")} />
        <input type="hidden" name="ride[destination_lat]" value={Map.get(@wizard_data, "destination_lat", "")} />
        <input type="hidden" name="ride[destination_long]" value={Map.get(@wizard_data, "destination_long", "")} />
        <input type="hidden" name="ride[ride_date]" value={Map.get(@wizard_data, "ride_date", "")} />
        <input type="hidden" name="ride[description]" value={Map.get(@wizard_data, "description", "")} />
        
        <div class="flex gap-3 pt-6">
          <button
            type="button"
            phx-click="prev_step"
            class="btn btn-outline btn-modern flex-1 flex items-center justify-center gap-2"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Edit
          </button>
          <button
            type="submit"
            class="btn btn-success btn-modern flex-1 flex items-center justify-center gap-2"
          >
            <.icon name="hero-check" class="w-4 h-4" /> Post My Ride Request
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
    <div :if={@rides == []} class="text-center py-12">
      <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-6">
        <.icon name="hero-truck" class="w-8 h-8 text-primary" />
      </div>
      <h3 class="text-lg font-semibold text-base-content mb-2">No rides yet</h3>
      <p class="text-base-content/70 mb-8">
        Ready to get started? Request your first ride!
      </p>
      <button
        phx-click="show_form"
        class="btn btn-primary btn-modern px-6 py-3 flex items-center gap-2 mx-auto"
      >
        <.icon name="hero-plus" class="w-5 h-5" /> Request Your First Ride
      </button>
    </div>
    
    <div :if={@rides != []} class="space-y-6">
      <!-- Pending Rides -->
      <div :if={@pending_rides != []}>
        <div class="flex items-center gap-2 mb-3">
          <.icon name="hero-clock" class="w-4 h-4 text-warning" />
          <h3 class="text-sm font-semibold text-warning">Pending Rides</h3>
          <span class="text-xs text-base-content/60">({length(@pending_rides)})</span>
        </div>
        <div class="space-y-3">
          <.compact_ride_card 
            :for={ride <- @pending_rides} 
            ride={ride} 
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>
      
      <!-- Confirmed Rides -->
      <div :if={@confirmed_rides != []}>
        <div class="flex items-center gap-2 mb-3">
          <.icon name="hero-check-circle" class="w-4 h-4 text-success" />
          <h3 class="text-sm font-semibold text-success">Confirmed Rides</h3>
          <span class="text-xs text-base-content/60">({length(@confirmed_rides)})</span>
        </div>
        <div class="space-y-3">
          <.compact_ride_card 
            :for={ride <- @confirmed_rides} 
            ride={ride} 
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>
      
      <!-- Completed Rides -->
      <div :if={@completed_rides != []}>
        <div class="flex items-center gap-2 mb-3">
          <.icon name="hero-check-badge" class="w-4 h-4 text-primary" />
          <h3 class="text-sm font-semibold text-primary">Completed Rides</h3>
          <span class="text-xs text-base-content/60">({length(@completed_rides)})</span>
        </div>
        <div class="space-y-3">
          <.compact_ride_card 
            :for={ride <- @completed_rides} 
            ride={ride} 
            volunteer_indices={@volunteer_indices}
          />
        </div>
      </div>
      
      <!-- Cancelled Rides -->
      <div :if={@cancelled_rides != []}>
        <div class="flex items-center gap-2 mb-3">
          <.icon name="hero-x-circle" class="w-4 h-4 text-error" />
          <h3 class="text-sm font-semibold text-error">Cancelled Rides</h3>
          <span class="text-xs text-base-content/60">({length(@cancelled_rides)})</span>
        </div>
        <div class="space-y-3">
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
    <div class="bg-base-100 border rounded-lg hover:shadow-md transition-shadow">
      <div class="p-4">
        <!-- Main ride info - always visible -->
        <div class="flex items-center justify-between">
          <div 
            class="flex items-center gap-3 flex-1 cursor-pointer hover:bg-base-200/50 -m-2 p-2 rounded"
            phx-click="show_ride_details"
            phx-value-ride_id={@ride.id}
          >
            <div class="flex-shrink-0">
              <.icon name="hero-truck" class="w-5 h-5 text-primary" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-1">
                <p class="font-medium text-sm truncate">
                  {@ride.pickup_name} → {@ride.destination_name}
                </p>
                <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium " <> status_badge_class(@ride.status)}>
                  {format_status(@ride.status)}
                </span>
              </div>
              <p class="text-xs text-base-content/60 flex items-center gap-1">
                <.icon name="hero-clock" class="w-3 h-3" />
                {Calendar.strftime(@ride.ride_date, "%b %d, %I:%M %p")}
              </p>
            </div>
            <div class="flex-shrink-0">
              <.icon name="hero-chevron-right" class="w-4 h-4 text-base-content/40" />
            </div>
          </div>
          
          <div class="flex items-center gap-2 ml-4">
            <!-- Volunteer count indicator -->
            <div :if={@ride.status == "pending" && @ride.volunteer_requests && length(@ride.volunteer_requests) > 0} class="flex items-center gap-1 text-xs text-primary">
              <.icon name="hero-hand-raised" class="w-4 h-4" />
              {length(@ride.volunteer_requests)}
            </div>
            
            <!-- Chat button for confirmed rides -->
            <button 
              :if={@ride.status == "confirmed"}
              onclick="window.location.href='/dashboard/inbox'"
              class="btn btn-primary btn-xs"
            >
              <.icon name="hero-chat-bubble-left-right" class="w-3 h-3" />
              Chat
            </button>
            
            <!-- Delete button -->
            <button
              phx-click="delete"
              phx-value-id={@ride.id}
              data-confirm="Are you sure you want to delete this ride request?"
              class="btn btn-ghost btn-xs p-1 hover:bg-error/10 hover:text-error"
            >
              <.icon name="hero-trash" class="w-3 h-3" />
            </button>
          </div>
        </div>
        
        <!-- Description if present -->
        <div :if={@ride.description && @ride.description != ""} class="mt-3 pt-3 border-t border-base-300">
          <p class="text-xs text-base-content/70 bg-base-200 p-2 rounded">
            {@ride.description}
          </p>
        </div>
        
        <!-- Volunteer section for pending rides -->
        <div :if={@ride.status == "pending" && @ride.volunteer_requests && length(@ride.volunteer_requests) > 0} class="mt-4 pt-4 border-t border-primary/20">
          <div class="flex items-center justify-between mb-3">
            <p class="text-sm font-medium text-primary">Volunteers Available</p>
            <span class="text-xs text-base-content/60">
              {length(@ride.volunteer_requests)} waiting
            </span>
          </div>
          <.volunteer_browser 
            requests={@ride.volunteer_requests}
            current_index={Map.get(@volunteer_indices, @ride.id, 0)}
            ride_id={@ride.id}
          />
        </div>
        
        <!-- Confirmed volunteer info -->
        <div :if={@ride.status == "confirmed" && @ride.volunteer} class="mt-4 pt-4 border-t border-success/20">
          <div class="flex items-center gap-3">
            <.avatar src={@ride.volunteer.profile_pic_location} alt="Volunteer" size="sm" />
            <div class="flex-1">
              <p class="text-sm font-medium text-success">Confirmed Volunteer</p>
              <p class="text-xs text-base-content/60">{@ride.volunteer.email}</p>
            </div>
            <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
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
        class="relative top-8 mx-auto p-6 border w-full max-w-4xl shadow-lg rounded-lg bg-base-100 m-4"
        phx-click-away="hide_ride_details"
      >
        <!-- Header -->
        <div class="flex justify-between items-start mb-6">
          <div class="flex items-center gap-3">
            <div class="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
              <.icon name="hero-truck" class="w-6 h-6 text-primary" />
            </div>
            <div>
              <h2 class="text-xl font-semibold text-base-content">
                Ride Details
              </h2>
              <span class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium " <> status_badge_class(@ride.status)}>
                {format_status(@ride.status)}
              </span>
            </div>
          </div>
          <button 
            phx-click="hide_ride_details" 
            class="btn btn-ghost btn-sm p-2 hover:bg-base-200 rounded-lg"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <!-- Ride Information -->
        <div class="grid md:grid-cols-2 gap-6 mb-8">
          <div class="space-y-4">
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-map-pin" class="w-4 h-4" /> Pickup Location
              </h3>
              <p class="font-semibold text-base-content">{@ride.pickup_name}</p>
              <p class="text-sm text-base-content/70">{@ride.pickup_address}</p>
            </div>
            
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-flag" class="w-4 h-4" /> Destination
              </h3>
              <p class="font-semibold text-base-content">{@ride.destination_name}</p>
              <p class="text-sm text-base-content/70">{@ride.destination_address}</p>
            </div>
          </div>
          
          <div class="space-y-4">
            <div>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-clock" class="w-4 h-4" /> Date & Time
              </h3>
              <p class="font-semibold text-base-content">
                {Calendar.strftime(@ride.ride_date, "%A, %B %d, %Y")}
              </p>
              <p class="text-sm text-base-content/70">
                {Calendar.strftime(@ride.ride_date, "%I:%M %p")}
              </p>
            </div>
            
            <div :if={@ride.description && @ride.description != ""}>
              <h3 class="text-sm font-medium text-base-content/80 mb-2 flex items-center gap-2">
                <.icon name="hero-document-text" class="w-4 h-4" /> Special Notes
              </h3>
              <p class="text-sm text-base-content bg-base-200 p-3 rounded-lg">
                {@ride.description}
              </p>
            </div>
          </div>
        </div>

        <!-- Status-specific sections -->
        <div class="space-y-6">
          <!-- Confirmed Volunteer (for confirmed rides) -->
          <div :if={@ride.status == "confirmed" && @ride.volunteer} class="border-t pt-6">
            <h3 class="text-lg font-semibold mb-4 text-success flex items-center gap-3">
              <.icon name="hero-check-circle" class="w-5 h-5" />
              Your Confirmed Volunteer
            </h3>
            <div class="bg-success/10 border border-success/20 p-6 rounded-lg">
              <div class="flex items-start gap-4 mb-4">
                <.avatar src={@ride.volunteer.profile_pic_location} alt="Volunteer Profile" size="lg" />
                <div class="flex-1">
                  <p class="font-semibold text-base text-base-content mb-1">
                    {@ride.volunteer.email}
                  </p>
                  <p class="text-sm text-base-content/70 flex items-center gap-1">
                    <.icon name="hero-phone" class="w-4 h-4" />
                    {@ride.volunteer.phone}
                  </p>
                </div>
                <.link
                  navigate={~p"/dashboard/inbox"}
                  class="btn btn-primary btn-sm flex items-center gap-2"
                >
                  <.icon name="hero-chat-bubble-left-right" class="w-4 h-4" />
                  Chat
                </.link>
              </div>
              <.volunteer_details volunteer={@ride.volunteer} />
            </div>
          </div>

          <!-- Volunteer Requests (for pending rides) -->
          <div :if={@ride.status == "pending" && @ride.volunteer_requests && length(@ride.volunteer_requests) > 0} class="border-t pt-6">
            <h3 class="text-lg font-semibold mb-4 text-primary flex items-center gap-3">
              <.icon name="hero-hand-raised" class="w-5 h-5" />
              Volunteers Available ({length(@ride.volunteer_requests)})
            </h3>
            <.volunteer_browser 
              requests={@ride.volunteer_requests}
              current_index={Map.get(@volunteer_indices, @ride.id, 0)}
              ride_id={@ride.id}
            />
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-between items-center mt-8 pt-6 border-t">
          <button
            phx-click="delete"
            phx-value-id={@ride.id}
            data-confirm="Are you sure you want to delete this ride request?"
            class="btn btn-error btn-outline btn-sm flex items-center gap-2"
          >
            <.icon name="hero-trash" class="w-4 h-4" />
            Delete Ride
          </button>
          
          <button 
            phx-click="hide_ride_details"
            class="btn btn-primary"
          >
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_browser(assigns) do
    ~H"""
    <div :if={@requests == []} class="text-center py-8 text-base-content/60 italic">
      No volunteer requests yet. Your ride will be visible to volunteers once posted.
    </div>
    <div :if={@requests != []} class="max-w-2xl mx-auto">
      <% current_request = Enum.at(@requests, @current_index) %>
      
      <!-- Progress indicator -->
      <div class="flex justify-center items-center mb-6">
        <span class="text-sm text-base-content/60 bg-base-200 px-3 py-1 rounded-full">
          Volunteer <%= @current_index + 1 %> of <%= length(@requests) %>
        </span>
      </div>
      
      <!-- Single volunteer card -->
      <div class="bg-primary/10 border-2 border-primary/20 p-6 rounded-lg">
        <div class="flex items-start gap-6 mb-6">
          <.avatar
            src={current_request.volunteer_user.profile_pic_location}
            alt="Volunteer Profile"
            size="xl"
          />
          <div class="flex-1">
            <p class="font-semibold text-lg text-base-content mb-1">
              {current_request.volunteer_user.email}
            </p>
            <p class="text-sm text-base-content/70 flex items-center gap-1">
              <.icon name="hero-phone" class="w-4 h-4" />
              {current_request.volunteer_user.phone}
            </p>
          </div>
        </div>
        
        <.volunteer_details volunteer={current_request.volunteer_user} />
        
        <div :if={current_request.message} class="mt-6">
          <p class="text-sm font-medium text-base-content/70 mb-2 flex items-center gap-2">
            <.icon name="hero-chat-bubble-bottom-center-text" class="w-5 h-5" />
            Message from Volunteer:
          </p>
          <p class="text-base bg-base-200 p-4 rounded-lg border-2 border-base-300 italic">
            "{current_request.message}"
          </p>
        </div>
        
        <!-- Navigation and action buttons -->
        <div class="flex justify-between items-center mt-6 pt-4 border-t border-primary/20">
          <button 
            phx-click="previous_volunteer" 
            phx-value-ride_id={@ride_id}
            class="btn btn-ghost btn-sm"
            disabled={length(@requests) <= 1}
          >
            <.icon name="hero-chevron-left" class="w-4 h-4" />
            Previous
          </button>
          
          <div class="flex gap-3">
            <button 
              phx-click="next_volunteer" 
              phx-value-ride_id={@ride_id}
              class="btn btn-outline btn-sm"
              disabled={length(@requests) <= 1}
            >
              <.icon name="hero-chevron-right" class="w-4 h-4" />
              Skip
            </button>
            <button
              phx-click="reject_volunteer"
              phx-value-request_id={current_request.id}
              class="btn btn-error btn-outline btn-sm px-4 flex items-center gap-2"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" /> Pass
            </button>
            <button
              phx-click="accept_volunteer"
              phx-value-request_id={current_request.id}
              phx-value-ride_id={@ride_id}
              class="btn btn-success btn-sm px-4 flex items-center gap-2"
              data-confirm="Accept this volunteer? This will confirm your ride and other volunteers will be notified."
            >
              <.icon name="hero-heart" class="w-5 h-5" /> Accept
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_details(assigns) do
    ~H"""
    <div class="grid md:grid-cols-2 gap-6">
      <div>
        <p class="text-sm font-medium text-base-content/70 mb-2 flex items-center gap-2">
          <.icon name="hero-identification" class="w-5 h-5" /> License Plate
        </p>
        <p class="text-base font-semibold text-base-content">
          {@volunteer.volunteer_license_plate || "Not provided"}
        </p>
      </div>
      <div>
        <p class="text-sm font-medium text-base-content/70 mb-2 flex items-center gap-2">
          <.icon name="hero-truck" class="w-5 h-5" /> Car Details
        </p>
        <p class="text-base font-semibold text-base-content">
          {@volunteer.volunteer_car || "Not provided"}
        </p>
      </div>
      <div :if={@volunteer.volunteer_bio} class="md:col-span-2">
        <p class="text-sm font-medium text-base-content/70 mb-2 flex items-center gap-2">
          <.icon name="hero-user" class="w-5 h-5" /> About This Volunteer
        </p>
        <p class="text-sm text-base-content/80 bg-base-200 p-3 rounded-lg">
          {@volunteer.volunteer_bio}
        </p>
      </div>
    </div>
    """
  end

  # Helper functions
  defp status_badge_class("pending"), do: "bg-warning/20 text-warning border border-warning/30"
  defp status_badge_class("confirmed"), do: "bg-success/20 text-success border border-success/30"
  defp status_badge_class("completed"), do: "bg-primary/20 text-primary border border-primary/30"
  defp status_badge_class("cancelled"), do: "bg-error/20 text-error border border-error/30"
  defp status_badge_class(_), do: "bg-neutral/20 text-neutral border border-neutral/30"

  defp format_status("pending"), do: "Waiting for Volunteer"
  defp format_status("confirmed"), do: "Volunteer Assigned"
  defp format_status("completed"), do: "Ride Completed"
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
