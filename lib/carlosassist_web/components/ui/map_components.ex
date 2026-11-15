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
  attr :class, :string, default: "h-80"

  def privacy_radius_map(assigns) do
    # Generate unique ID for each map instance
    map_id =
      "privacy-map-#{assigns.location_type}-#{assigns.ride.id}-#{System.unique_integer([:positive])}"

    assigns = assign(assigns, :map_id, map_id)

    ~H"""
    <div class={["map-frame", @class]}>
      <div
        id={@map_id}
        class="map-canvas"
        phx-hook="PrivacyRadiusMap"
        data-ride-id={@ride.id}
        data-location-type={@location_type}
        data-pickup-lat={@ride.pickup_lat}
        data-pickup-lng={@ride.pickup_long}
        data-destination-lat={@ride.destination_lat}
        data-destination-lng={@ride.destination_long}
      >
      </div>

      <div class="map-legend">
        <div class="map-legend-row">
          <span class="map-dot"></span>
          <span>
            {if @location_type == :pickup, do: "Pickup area", else: "Destination area"} (half a mile)
          </span>
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
  attr :class, :string, default: "h-80"

  def exact_location_map(assigns) do
    # Generate unique ID for each map instance
    map_id = "exact-map-#{assigns.ride.id}-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :map_id, map_id)

    ~H"""
    <div class={["map-frame", @class]}>
      <div
        id={@map_id}
        class="map-canvas"
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

      <div class="map-legend">
        <div class="map-legend-row">
          <span class="map-dot map-dot-pickup"></span>
          <span>Pickup</span>
        </div>
        <div class="map-legend-row">
          <span class="map-dot map-dot-destination"></span>
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
  attr :class, :string, default: "h-80"

  def smart_location_map(assigns) do
    can_see_exact = LocationPrivacy.can_see_exact_location?(assigns.ride, assigns.current_user)
    assigns = assign(assigns, :can_see_exact, can_see_exact)

    ~H"""
    <div class="grid gap-5">
      <%= if @can_see_exact do %>
        <div>
          <p class="data-label mb-2">
            <.icon name="hero-lock-open" class="size-5" /> Exact addresses
          </p>
          <.exact_location_map ride={@ride} class={@class} />
        </div>
      <% else %>
        <div class="notice">
          <.icon name="hero-lock-closed" />
          <p>You see the exact addresses once the rider chooses you.</p>
        </div>

        <div :if={@location_type in [:pickup, :both]}>
          <p class="data-label mb-2">Pickup area: {@ride.pickup_name}</p>
          <.privacy_radius_map ride={@ride} location_type={:pickup} class={@class} />
        </div>

        <div :if={@location_type in [:destination, :both]}>
          <p class="data-label mb-2">Destination area: {@ride.destination_name}</p>
          <.privacy_radius_map ride={@ride} location_type={:destination} class={@class} />
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
    <div class="data-grid">
      <.location_card label="Pickup" icon="hero-map-pin" info={@pickup_info} />
      <.location_card label="Going to" icon="hero-flag" info={@destination_info} />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :info, :map, required: true

  defp location_card(assigns) do
    ~H"""
    <div class="inset">
      <div class="mb-2 flex items-start justify-between gap-3">
        <p class="data-label"><.icon name={@icon} class="size-5" /> {@label}</p>
        <span :if={@info.privacy_protected} class="badge badge-notice">General area</span>
        <span :if={!@info.privacy_protected} class="badge badge-positive">Exact</span>
      </div>
      <p class="data-value">{@info.name}</p>
      <p :if={@info.address} class="data-note">{@info.address}</p>
      <p :if={!@info.address} class="data-note">
        You see the exact address once the rider chooses you.
      </p>
    </div>
    """
  end
end
