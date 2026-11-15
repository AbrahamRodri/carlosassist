defmodule CarlosassistWeb.PageController do
  use CarlosassistWeb, :controller

  def home(conn, _params) do
    # The home page draws its own header and footer, so the root layout
    # leaves its app header out when :home_page is set.
    conn
    |> assign(:home_page, true)
    |> assign(:page_title, "Rides from parish volunteers")
    |> render(:home, layout: false)
  end
end
