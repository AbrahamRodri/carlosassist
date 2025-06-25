defmodule Carlosassist.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CarlosassistWeb.Telemetry,
      Carlosassist.Repo,
      {DNSCluster, query: Application.get_env(:carlosassist, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Carlosassist.PubSub},
      # Start a worker by calling: Carlosassist.Worker.start_link(arg)
      # {Carlosassist.Worker, arg},
      # Start to serve requests, typically the last entry
      CarlosassistWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Carlosassist.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CarlosassistWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
