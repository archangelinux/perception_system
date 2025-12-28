defmodule Simulation.Repo do
  use Ecto.Repo,
    otp_app: :simulation,
    adapter: Ecto.Adapters.Postgres
end
