defmodule OwlGateWeb.PageController do
  use OwlGateWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
