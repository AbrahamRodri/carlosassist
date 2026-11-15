defmodule CarlosassistWeb.PageController do
  use CarlosassistWeb, :controller

  def home(conn, _params) do
    # The home page lays out its own full-width bands, so it is rendered
    # without the app layout; the root layout still gives it the site
    # header and footer.
    conn
    |> assign(:page_title, "Rides from parish volunteers")
    |> render(:home, layout: false)
  end
end
