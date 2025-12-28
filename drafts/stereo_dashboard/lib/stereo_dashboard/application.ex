defmodule StereoDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StereoDashboardWeb.Telemetry,
      #StereoDashboard.Repo, #postgres database
      {DNSCluster, query: Application.get_env(:stereo_dashboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: StereoDashboard.PubSub},
      # Start a worker by calling: StereoDashboard.Worker.start_link(arg)
      # {StereoDashboard.Worker, arg},
      # Start to serve requests, typically the last entry
      StereoDashboardWeb.Endpoint,
      StereoDashboard.CameraServer #added module from camera_server.ex
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StereoDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StereoDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
