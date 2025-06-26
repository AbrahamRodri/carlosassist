defmodule CarlosassistWeb.VolunteerDashboardLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :rides, mock_rides())}
  end

  defp mock_rides do
    [
      %{id: 1, rider: "Rider A", status: "Pending"},
      %{id: 2, rider: "Rider B", status: "Completed"}
    ]
  end

  def render(assigns) do
    ~H"""
    <h1>Volunteer Dashboard</h1>
    <ul>
      <li :for={ride <- @rides}>
        Ride {ride.id}: {ride.rider} - {ride.status}
      </li>
    </ul>
    """
  end
end
