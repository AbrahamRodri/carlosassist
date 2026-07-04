defmodule CarlosassistWeb.PageControllerTest do
  use CarlosassistWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "CarlosAssist"
  end
end
