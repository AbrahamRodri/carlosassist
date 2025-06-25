defmodule Carlosassist.Repo do
  use Ecto.Repo,
    otp_app: :carlosassist,
    adapter: Ecto.Adapters.Postgres
end
