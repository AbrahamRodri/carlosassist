defmodule CarlosassistWeb.ErrorHTMLTest do
  use CarlosassistWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    html = render_to_string(CarlosassistWeb.ErrorHTML, "404", "html", [])
    assert html =~ "Not Found"
    assert html =~ "We could not find that page"
  end

  test "renders 500.html" do
    html = render_to_string(CarlosassistWeb.ErrorHTML, "500", "html", [])
    assert html =~ "Internal Server Error"
    assert html =~ "Something went wrong on our side"
  end
end
