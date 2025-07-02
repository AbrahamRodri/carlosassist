defmodule CarlosassistWeb.VolunteerDashboardLive do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Rides

  # Helper function to get rides available for a volunteer (excluding rides they've already requested)
  defp get_available_rides_for_volunteer(volunteer_user_id) do
    all_pending_rides = Rides.list_pending_rides_for_volunteers()

    requested_ride_ids =
      Rides.list_volunteer_requests_for_user(volunteer_user_id)
      |> Enum.map(& &1.ride_id)
      |> MapSet.new()

    Enum.filter(all_pending_rides, fn ride ->
      not MapSet.member?(requested_ride_ids, ride.id)
    end)
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    my_requests = Rides.list_volunteer_requests_for_user(current_user.id)
    available_rides = get_available_rides_for_volunteer(current_user.id)

    {:ok,
     socket
     |> assign(:pending_rides, available_rides)
     |> assign(:my_requests, my_requests)
     |> assign(:show_request_modal, false)
     |> assign(:selected_ride, nil)
     |> assign(:request_message, "")}
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
        {:noreply,
         socket
         |> put_flash(:info, "Your request has been sent to the rider!")
         |> assign(:show_request_modal, false)
         |> assign(:selected_ride, nil)
         |> assign(:my_requests, Rides.list_volunteer_requests_for_user(current_user.id))
         |> assign(:pending_rides, get_available_rides_for_volunteer(current_user.id))}

      {:error, changeset} ->
        error_message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply, put_flash(socket, :error, "Error: #{error_message}")}
    end
  end

  # The render function is now handled by the corresponding .html.heex template
end
