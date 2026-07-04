defmodule CarlosassistWeb.VolunteerDashboardLive do
  @moduledoc """
  Volunteer home (`/dashboard/volunteer`): browse open rides one-at-a-time
  (carousel style), send an offer with a message, and track my offers. Rides the
  volunteer already offered on are filtered out. Not PubSub-subscribed — the board
  refreshes only on reload. Template: volunteer_dashboard_live.html.heex.
  """
  use CarlosassistWeb, :live_view

  alias Carlosassist.Rides

  # Helper function to get rides available for a volunteer (excluding rides they've already requested)
  defp get_available_rides_for_volunteer(volunteer_user_id) do
    all_pending_rides = Rides.list_pending_rides_for_volunteers()

    requested_ride_ids =
      Rides.list_volunteer_requests_for_user(volunteer_user_id)
      |> Enum.map(& &1.ride_id)
      |> MapSet.new()

    all_pending_rides
    |> Enum.filter(fn ride ->
      not MapSet.member?(requested_ride_ids, ride.id)
    end)
    |> Enum.map(fn ride ->
      conversation = Carlosassist.Messages.get_conversation_by_ride(ride.id)
      Map.put(ride, :conversation, conversation)
    end)
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    my_requests = Rides.list_volunteer_requests_for_user(current_user.id)
    |> Enum.map(fn request ->
      conversation = Carlosassist.Messages.get_conversation_by_ride(request.ride_id)
      %{request | ride: Map.put(request.ride, :conversation, conversation)}
    end)
    available_rides = get_available_rides_for_volunteer(current_user.id)

    {:ok,
     socket
     |> assign(:pending_rides, available_rides)
     |> assign(:my_requests, my_requests)
     |> assign(:show_request_modal, false)
     |> assign(:selected_ride, nil)
     |> assign(:request_message, "")
     |> assign(:current_ride_index, 0)
     |> assign(:show_request_details, false)
     |> assign(:detailed_request, nil)}
  end

  def handle_event("request_ride", %{"ride_id" => ride_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_request_modal, true)
     |> assign(:selected_ride, String.to_integer(ride_id))
     |> assign(:request_message, "")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_request_modal, false)
     |> assign(:selected_ride, nil)}
  end

  def handle_event("update_message", %{"value" => message}, socket) do
    {:noreply, assign(socket, :request_message, message)}
  end

  def handle_event("submit_request", %{"message" => message}, socket) do
    current_user = socket.assigns.current_scope.user

    case Rides.create_volunteer_request(%{
           ride_id: socket.assigns.selected_ride,
           volunteer_user_id: current_user.id,
           message: message
         }) do
      {:ok, _request} ->
        updated_rides = get_available_rides_for_volunteer(current_user.id)
        # Adjust current_ride_index if needed after removing a ride
        new_index = min(socket.assigns.current_ride_index, max(0, length(updated_rides) - 1))
        
        {:noreply,
         socket
         |> put_flash(:info, "Your request has been sent to the rider!")
         |> assign(:show_request_modal, false)
         |> assign(:selected_ride, nil)
         |> assign(:my_requests, Rides.list_volunteer_requests_for_user(current_user.id))
         |> assign(:pending_rides, updated_rides)
         |> assign(:current_ride_index, new_index)}

      {:error, changeset} ->
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Error: #{error_message}")}
    end
  end

  def handle_event("next_ride", _params, socket) do
    rides = socket.assigns.pending_rides
    current_index = socket.assigns.current_ride_index
    new_index = if current_index + 1 >= length(rides), do: 0, else: current_index + 1
    
    {:noreply, assign(socket, :current_ride_index, new_index)}
  end

  def handle_event("previous_ride", _params, socket) do
    rides = socket.assigns.pending_rides
    current_index = socket.assigns.current_ride_index
    new_index = if current_index - 1 < 0, do: max(0, length(rides) - 1), else: current_index - 1
    
    {:noreply, assign(socket, :current_ride_index, new_index)}
  end

  def handle_event("show_request_details", %{"request_id" => request_id}, socket) do
    request = Enum.find(socket.assigns.my_requests, &(&1.id == String.to_integer(request_id)))
    
    {:noreply,
     socket
     |> assign(:show_request_details, true)
     |> assign(:detailed_request, request)}
  end

  def handle_event("hide_request_details", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_request_details, false)
     |> assign(:detailed_request, nil)}
  end

  # The render function is now handled by the corresponding .html.heex template
end
