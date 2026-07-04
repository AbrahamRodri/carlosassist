defmodule Carlosassist.Uploads do
  @moduledoc """
  Stores user-uploaded files (profile pictures) under the configured
  `:carlosassist, :uploads_dir` — `priv/static/uploads` in dev/test, the mounted
  Fly volume in prod so files survive deploys. Served by
  `CarlosassistWeb.UploadsController` (not Plug.Static, whose root is baked into
  the release image).
  """

  def dir, do: Application.fetch_env!(:carlosassist, :uploads_dir)

  def profile_pics_dir, do: Path.join(dir(), "profile_pics")

  @doc """
  Copies an uploaded temp file into the profile-pics dir under a sanitized,
  unique name. Returns the URL path to store on the user record.
  """
  def store_profile_pic!(src_path, unique_prefix, client_name) do
    filename = "#{unique_prefix}-#{sanitize(client_name)}"
    File.mkdir_p!(profile_pics_dir())
    File.cp!(src_path, Path.join(profile_pics_dir(), filename))
    "/uploads/profile_pics/#{filename}"
  end

  @doc """
  Absolute path of a stored profile pic, or `:error` if the name is unsafe
  (traversal, wrong extension) or the file doesn't exist.
  """
  def fetch_profile_pic_path(filename) do
    if safe_filename?(filename) do
      path = Path.join(profile_pics_dir(), filename)
      if File.regular?(path), do: {:ok, path}, else: :error
    else
      :error
    end
  end

  defp safe_filename?(filename) do
    Path.basename(filename) == filename and
      not String.contains?(filename, ["..", "/", "\\"]) and
      String.downcase(Path.extname(filename)) in ~w(.jpg .jpeg .png .webp)
  end

  defp sanitize(name), do: String.replace(name, ~r/[^\w.-]+/, "-")
end
