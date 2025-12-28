defmodule StereoDashboardWeb.PageController do
  use StereoDashboardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
