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
    ~H"""
    <div :if={@rides == []} class="text-center py-16">
      <div class="w-24 h-24 bg-slate-100 rounded-full flex items-center justify-center mx-auto mb-6">
        <.icon name="hero-truck" class="w-12 h-12 text-base-content/40" />
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
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-lg font-semibold text-base-content">Your Rides</h2>
        <span class="text-sm text-base-content/60">{length(@rides)} total</span>
      </div>
      <div class="grid gap-4">
        <.ride_card :for={ride <- @rides} ride={ride} />
      </div>
    </div>
    """
  end

  defp ride_card(assigns) do
    ~H"""
    <div class="card-modern transition-all duration-200 hover:scale-[1.01]">
      <div class="p-6">
        <div class="flex justify-between items-start mb-4">
          <div class="flex-1">
            <div class="flex items-center gap-3 mb-3">
              <div class="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                <.icon name="hero-truck" class="w-5 h-5 text-primary" />
              </div>
              <div>
                <h3 class="text-base font-semibold text-base-content">
                  {@ride.pickup_name} → {@ride.destination_name}
                </h3>
                <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <> status_badge_class(@ride.status)}>
                  {format_status(@ride.status)}
                </span>
              </div>
            </div>

            <div class="space-y-1 text-sm text-base-content/70">
              <div class="flex items-center gap-2">
                <.icon name="hero-clock" class="w-4 h-4" />
                <span>{Calendar.strftime(@ride.ride_date, "%A, %B %d, %Y at %I:%M %p")}</span>
              </div>
            </div>

            <p
              :if={@ride.description && @ride.description != ""}
              class="mt-3 text-sm text-base-content/70 bg-base-200 p-3 rounded-lg"
            >
              {@ride.description}
            </p>
          </div>

          <div class="ml-4">
            <button
              phx-click="delete"
              phx-value-id={@ride.id}
              data-confirm="Are you sure you want to delete this ride request?"
              class="btn btn-ghost btn-sm p-2 hover:bg-error/10 hover:text-error rounded-lg"
            >
              <.icon name="hero-trash" class="w-4 h-4" />
            </button>
          </div>
        </div>
        
    <!-- Assigned Volunteer Section (for confirmed rides) -->
        <div
          :if={@ride.status == "confirmed" && @ride.volunteer}
          class="mt-8 border-t-4 border-success pt-6"
        >
          <h4 class="text-lg font-semibold mb-4 text-success flex items-center gap-3">
            <.icon name="hero-check-circle" class="w-6 h-6" />
            <span>Your Volunteer</span>
          </h4>
          <div class="bg-success/10 border-2 border-success/30 p-6 rounded-lg">
            <div class="flex items-start gap-6 mb-6">
              <.avatar src={@ride.volunteer.profile_pic_location} alt="Volunteer Profile" size="xl" />
              <div class="flex-1">
                <p class="font-semibold text-base text-base-content mb-1">
                  {@ride.volunteer.email}
                </p>
                <p class="text-sm text-base-content/70">
                  <.icon name="hero-phone" class="w-4 h-4" />
                  {@ride.volunteer.phone}
                </p>
              </div>
            </div>
            <.volunteer_details volunteer={@ride.volunteer} />
            <div class="mt-6">
              <.link
                navigate={~p"/dashboard/inbox"}
                class="btn btn btn-primary btn-modern px-6 flex items-center gap-2"
              >
                <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" /> Chat with Your Volunteer
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
          class="mt-8 border-t-4 border-primary pt-6"
        >
          <h4 class="text-lg font-semibold mb-4 text-primary flex items-center gap-3">
            <.icon name="hero-hand-raised" class="w-6 h-6" />
            <span>Volunteers Want to Help ({length(@ride.volunteer_requests)})</span>
          </h4>
          <div class="space-y-6">
            <.volunteer_request_card
              :for={request <- @ride.volunteer_requests}
              request={request}
              ride={@ride}
            />
          </div>
        </div>

        <div class="mt-6 text-center">
          <div class="text-sm text-base-content/60">
            Posted {time_ago(@ride.inserted_at)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp volunteer_request_card(assigns) do
    ~H"""
    <div class="bg-primary/10 border-2 border-primary/20 p-6 rounded-lg">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <div class="flex items-start gap-6 mb-6">
            <.avatar
              src={@request.volunteer_user.profile_pic_location}
              alt="Volunteer Profile"
              size="xl"
            />
            <div class="flex-1">
              <p class="font-semibold text-base text-base-content mb-1">
                {@request.volunteer_user.email}
              </p>
              <p class="text-sm text-base-content/70">
                <.icon name="hero-phone" class="w-4 h-4" />
                {@request.volunteer_user.phone}
              </p>
            </div>
          </div>
          <.volunteer_details volunteer={@request.volunteer_user} />
          <div :if={@request.message} class="mt-6">
            <p class="text-sm font-medium text-base-content/70 mb-2 flex items-center gap-2">
              <.icon name="hero-chat-bubble-bottom-center-text" class="w-5 h-5" />
              Message from Volunteer:
            </p>
            <p class="text-lg bg-base-200 p-4 rounded-lg border-2 border-base-300 italic">
              "{@request.message}"
            </p>
          </div>
        </div>
        <div class="flex flex-col gap-3 ml-6">
          <button
            phx-click="accept_volunteer"
            phx-value-request_id={@request.id}
            phx-value-ride_id={@ride.id}
            class="btn btn-success btn-modern px-6 flex items-center gap-2"
            data-confirm="Accept this volunteer? This will confirm your ride and other volunteers will be notified."
          >
            <.icon name="hero-check" class="w-4 h-4" /> Accept
          </button>
          <button
            phx-click="reject_volunteer"
            phx-value-request_id={@request.id}
            class="btn btn-error btn-outline btn-modern px-6 flex items-center gap-2"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" /> Decline
          </button>
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
