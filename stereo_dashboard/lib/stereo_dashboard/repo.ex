defmodule StereoDashboard.Repo do
  use Ecto.Repo,
    otp_app: :stereo_dashboard,
    adapter: Ecto.Adapters.Postgres
end
