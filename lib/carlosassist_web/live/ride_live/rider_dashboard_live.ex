defmodule CarlosassistWeb.RideLive.RiderDashboardLive do
  use CarlosassistWeb, :live_view

  alias CarlosassistWeb.RideComponent

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_scope, socket.assigns.current_scope)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>My Rides</h1>
      <p>Current scope: {inspect(@current_scope)}</p>
      <.live_component module={RideComponent} id="ride_component" current_scope={@current_scope} />
    </div>
    """
  end
end
