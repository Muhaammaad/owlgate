defmodule OwlGateWeb.Plugs.RequireAuthenticatedJson do
  @moduledoc "Halts with 401 JSON unless `conn.assigns.current_user` is set."

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{error: "unauthenticated"}))
      |> halt()
    end
  end
end
