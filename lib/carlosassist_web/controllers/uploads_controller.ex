defmodule CarlosassistWeb.UploadsController do
  @moduledoc """
  Serves uploaded profile pictures from the runtime-configured uploads dir
  (Fly volume in prod). Filenames are UUID-prefixed, so long-lived caching is safe.
  """
  use CarlosassistWeb, :controller

  alias Carlosassist.Uploads

  def profile_pic(conn, %{"filename" => filename}) do
    case Uploads.fetch_profile_pic_path(filename) do
      {:ok, path} ->
        conn
        |> put_resp_content_type(MIME.from_path(path))
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_file(200, path)

      :error ->
        send_resp(conn, 404, "Not Found")
    end
  end
end
