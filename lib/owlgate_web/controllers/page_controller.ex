defmodule OwlGateWeb.PageController do
  use OwlGateWeb, :controller

  def home(conn, _params) do
    render(conn, :home, csrf_token: Plug.CSRFProtection.get_csrf_token())
  end
end
