defmodule CarlosassistWeb.UI.MapComponents do
  use Phoenix.Component
  alias Carlosassist.LocationPrivacy
  import CarlosassistWeb.CoreComponents

  @doc """
  Renders a privacy radius map for volunteers.

  Shows a 1-mile radius circle around the actual location
  without revealing the exact coordinates.
  """
  attr :ride, :map, required: true
  attr :location_type, :atom, required: true, values: [:pickup, :destination]
  attr :class, :string, default: "h-80 rounded-lg"

  def privacy_radius_map(assigns) do
    # Generate unique ID for each map instance
    map_id =
      "privacy-map-#{assigns.location_type}-#{assigns.ride.id}-#{System.unique_integer([:positive])}"

    assigns = assign(assigns, :map_id, map_id)

    ~H"""
    <div class={["relative bg-base-200 border border-base-300", @class]}>
      <div
        id={@map_id}
        class="w-full h-full rounded-lg"
        phx-hook="PrivacyRadiusMap"
        data-ride-id={@ride.id}
        data-location-type={@location_type}
        data-pickup-lat={@ride.pickup_lat}
        data-pickup-lng={@ride.pickup_long}
        data-destination-lat={@ride.destination_lat}
        data-destination-lng={@ride.destination_long}
      >
      </div>
      
    <!-- Map Controls -->
      <div class="absolute top-2 right-2 bg-base-100/90 backdrop-blur-sm rounded-lg p-3 text-xs space-y-1">
        <div class="flex items-center gap-2 text-primary font-medium">
          <span class="w-3 h-3 bg-primary/30 border-2 border-primary rounded-full"></span>
          <span>0.5-mile privacy area</span>
        </div>
        <div class="text-base-content/70 font-medium">
          <%= if @location_type == :pickup do %>
            <.icon name="hero-map-pin" class="w-3 h-3 inline" /> Pickup Location
          <% else %>
            <.icon name="hero-flag" class="w-3 h-3 inline" /> Destination
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an exact location map for authorized users.

  Shows precise locations with markers for pickup and destination.
  """
  attr :ride, :map, required: true
  attr :class, :string, default: "h-80 rounded-lg"

  def exact_location_map(assigns) do
    # Generate unique ID for each map instance
    map_id = "exact-map-#{assigns.ride.id}-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :map_id, map_id)

    ~H"""
    <div class={["relative bg-base-200 border border-base-300", @class]}>
      <div
        id={@map_id}
        class="w-full h-full rounded-lg"
        phx-hook="ExactLocationMap"
        data-ride-id={@ride.id}
        data-pickup-lat={@ride.pickup_lat}
        data-pickup-lng={@ride.pickup_long}
        data-pickup-name={@ride.pickup_name}
        data-pickup-address={@ride.pickup_address}
        data-destination-lat={@ride.destination_lat}
        data-destination-lng={@ride.destination_long}
        data-destination-name={@ride.destination_name}
        data-destination-address={@ride.destination_address}
      >
      </div>
      
    <!-- Map Controls -->
      <div class="absolute top-2 right-2 bg-base-100/90 backdrop-blur-sm rounded-lg p-2 text-xs space-y-1">
        <div class="flex items-center gap-1 text-success">
          <span class="w-3 h-3 bg-success rounded-full"></span>
          <span>Pickup</span>
        </div>
        <div class="flex items-center gap-1 text-error">
          <span class="w-3 h-3 bg-error rounded-full"></span>
          <span>Destination</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Smart map component that automatically shows privacy or exact map
  based on user permissions.
  """
  attr :ride, :map, required: true
  attr :current_user, :map, required: true
  attr :location_type, :atom, default: :both, values: [:pickup, :destination, :both]
  attr :class, :string, default: "h-80 rounded-lg"

  def smart_location_map(assigns) do
    can_see_exact = LocationPrivacy.can_see_exact_location?(assigns.ride, assigns.current_user)
    assigns = assign(assigns, :can_see_exact, can_see_exact)

    ~H"""
    <div class="space-y-4">
      <%= if @can_see_exact do %>
        <!-- Exact Location Map for Authorized Users -->
        <div class="space-y-2">
          <div class="flex items-center gap-2 text-success">
            <.icon name="hero-lock-open" class="w-5 h-5" />
            <span class="font-medium">Exact Locations</span>
            <span class="text-sm text-success/80">(You have access)</span>
          </div>
          <.exact_location_map ride={@ride} class={@class} />
        </div>
      <% else %>
        <!-- Privacy Radius Maps for Non-Authorized Users -->
        <div class="space-y-4">
          <div class="flex items-center gap-2 text-primary">
            <.icon name="hero-lock-closed" class="w-5 h-5" />
            <span class="font-medium">Privacy Protected Areas</span>
            <span class="text-sm text-primary/80">(0.5-mile radius)</span>
          </div>

          <%= if @location_type in [:pickup, :both] do %>
            <div>
              <h4 class="text-sm font-medium text-base-content/80 mb-2">
                Pickup Area: {@ride.pickup_name}
              </h4>
              <.privacy_radius_map ride={@ride} location_type={:pickup} class="h-80 rounded-lg" />
            </div>
          <% end %>

          <%= if @location_type in [:destination, :both] do %>
            <div>
              <h4 class="text-sm font-medium text-base-content/80 mb-2">
                Destination Area: {@ride.destination_name}
              </h4>
              <.privacy_radius_map ride={@ride} location_type={:destination} class="h-80 rounded-lg" />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders location summary cards with privacy-aware information.
  """
  attr :ride, :map, required: true
  attr :current_user, :map, required: true

  def location_summary_cards(assigns) do
    pickup_info = LocationPrivacy.get_location_info(assigns.ride, assigns.current_user, :pickup)

    destination_info =
      LocationPrivacy.get_location_info(assigns.ride, assigns.current_user, :destination)

    assigns =
      assigns
      |> assign(:pickup_info, pickup_info)
      |> assign(:destination_info, destination_info)

    ~H"""
    <div class="grid md:grid-cols-2 gap-4">
      <!-- Pickup Card -->
      <div class="card bg-base-100 border border-base-300 p-4">
        <div class="flex items-start justify-between mb-2">
          <h3 class="font-medium text-base-content flex items-center gap-2">
            <.icon name="hero-map-pin" class="w-4 h-4" /> Pickup
          </h3>
          <%= if @pickup_info.privacy_protected do %>
            <span class="badge badge-primary badge-sm">Protected</span>
          <% else %>
            <span class="badge badge-success badge-sm">Exact</span>
          <% end %>
        </div>

        <div class="space-y-2">
          <div>
            <span class="text-sm text-base-content/60">Location:</span>
            <p class="font-medium">{@pickup_info.name}</p>
          </div>

          <%= if @pickup_info.address do %>
            <div>
              <span class="text-sm text-base-content/60">Address:</span>
              <p class="text-sm">{@pickup_info.address}</p>
            </div>
          <% else %>
            <p class="text-xs text-primary">
              Exact address will be shared after volunteer acceptance
            </p>
          <% end %>
        </div>
      </div>
      
    <!-- Destination Card -->
      <div class="card bg-base-100 border border-base-300 p-4">
        <div class="flex items-start justify-between mb-2">
          <h3 class="font-medium text-base-content flex items-center gap-2">
            <.icon name="hero-flag" class="w-4 h-4" /> Destination
          </h3>
          <%= if @destination_info.privacy_protected do %>
            <span class="badge badge-primary badge-sm">Protected</span>
          <% else %>
            <span class="badge badge-success badge-sm">Exact</span>
          <% end %>
        </div>

        <div class="space-y-2">
          <div>
            <span class="text-sm text-base-content/60">Location:</span>
            <p class="font-medium">{@destination_info.name}</p>
          </div>

          <%= if @destination_info.address do %>
            <div>
              <span class="text-sm text-base-content/60">Address:</span>
              <p class="text-sm">{@destination_info.address}</p>
            </div>
          <% else %>
            <p class="text-xs text-primary">
              Exact address will be shared after volunteer acceptance
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
