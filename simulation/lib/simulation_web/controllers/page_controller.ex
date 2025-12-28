defmodule SimulationWeb.PageController do
  use SimulationWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
