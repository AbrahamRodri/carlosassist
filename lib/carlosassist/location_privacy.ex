defmodule Carlosassist.LocationPrivacy do
  @moduledoc """
  Context for handling location privacy features.
  
  This module implements the 3-mile radius privacy system where:
  - Before volunteer match: Only show location nicknames and general area
  - After volunteer match: Reveal exact addresses to matched volunteer
  """


  @privacy_radius_miles 3
  @privacy_radius_meters @privacy_radius_miles * 1609.344

  @doc """
  Determines if a user can see exact location details for a ride.
  
  Rules:
  - Ride creator (rider) can always see exact details
  - Matched volunteer can see exact details
  - Other volunteers can only see privacy-protected info
  """
  def can_see_exact_location?(ride, user) do
    cond do
      # Ride creator can always see exact details
      ride.user_id == user.id -> true
      
      # Matched volunteer can see exact details
      ride.volunteer_id == user.id -> true
      
      # All other users cannot see exact details
      true -> false
    end
  end

  @doc """
  Returns location information with appropriate privacy filtering.
  
  For authorized users: Returns exact address
  For non-authorized users: Returns only the friendly name
  """
  def get_location_info(ride, user, location_type) when location_type in [:pickup, :destination] do
    can_see_exact = can_see_exact_location?(ride, user)
    
    case location_type do
      :pickup ->
        %{
          name: ride.pickup_name,
          address: if(can_see_exact, do: ride.pickup_address, else: nil),
          lat: if(can_see_exact, do: ride.pickup_lat, else: nil),
          long: if(can_see_exact, do: ride.pickup_long, else: nil),
          privacy_protected: !can_see_exact
        }
      
      :destination ->
        %{
          name: ride.destination_name,
          address: if(can_see_exact, do: ride.destination_address, else: nil),
          lat: if(can_see_exact, do: ride.destination_lat, else: nil),
          long: if(can_see_exact, do: ride.destination_long, else: nil),
          privacy_protected: !can_see_exact
        }
    end
  end

  @doc """
  Generates privacy radius coordinates for map display.
  
  Returns a circle with the specified radius around the actual location.
  Used to show volunteers the general area without revealing exact location.
  """
  def get_privacy_radius_coords(lat, lng) do
    # Convert Decimal to float if needed
    lat = convert_to_float(lat)
    lng = convert_to_float(lng)
    
    # Generate circle coordinates (36 points for smooth circle)
    points = for i <- 0..35 do
      angle = i * :math.pi() * 2 / 36
      
      # Calculate offset in meters, then convert to lat/lng
      lat_offset = @privacy_radius_meters * :math.cos(angle) / 111_111 # meters to degrees lat
      lng_offset = @privacy_radius_meters * :math.sin(angle) / (:math.cos(lat * :math.pi() / 180) * 111_111)
      
      %{
        lat: lat + lat_offset,
        lng: lng + lng_offset
      }
    end
    
    %{
      center: %{lat: lat, lng: lng},
      radius_miles: @privacy_radius_miles,
      coordinates: points
    }
  end

  @doc """
  Gets privacy radius data for a ride location.
  
  Returns nil if coordinates are not available.
  """
  def get_ride_privacy_radius(ride, location_type) when location_type in [:pickup, :destination] do
    {lat, lng} = case location_type do
      :pickup -> {ride.pickup_lat, ride.pickup_long}
      :destination -> {ride.destination_lat, ride.destination_long}
    end
    
    if lat && lng do
      get_privacy_radius_coords(lat, lng)
    else
      nil
    end
  end

  @doc """
  Formats location for display based on privacy level.
  
  Returns a user-friendly string representation.
  """
  def format_location_for_display(ride, user, location_type) do
    location_info = get_location_info(ride, user, location_type)
    
    if location_info.privacy_protected do
      "#{location_info.name} (General Area)"
    else
      if location_info.address do
        "#{location_info.name}: #{location_info.address}"
      else
        location_info.name
      end
    end
  end

  @doc """
  Checks if a ride has complete location data for privacy features.
  """
  def has_complete_location_data?(ride) do
    not is_nil(ride.pickup_lat) and 
    not is_nil(ride.pickup_long) and 
    not is_nil(ride.destination_lat) and 
    not is_nil(ride.destination_long)
  end

  @doc """
  Gets general area name for privacy display.
  
  This could be enhanced to use reverse geocoding to get 
  neighborhood/city names, but for now returns a simple format.
  """
  def get_general_area_name(lat, lng) when is_number(lat) and is_number(lng) do
    # Simple implementation - could be enhanced with reverse geocoding
    "Austin Area" # Placeholder - in production, use reverse geocoding
  end

  def get_general_area_name(_lat, _lng), do: "Local Area"

  # Private helper functions

  defp convert_to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp convert_to_float(value) when is_number(value), do: value * 1.0
  defp convert_to_float(_), do: 0.0
end