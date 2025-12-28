#for supervised OTP application
defmodule CameraSimElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: CameraSimElixir.Worker.start_link(arg)
      # {CameraSimElixir.Worker, arg}
      CameraSimElixir.CameraServer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CameraSimElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
