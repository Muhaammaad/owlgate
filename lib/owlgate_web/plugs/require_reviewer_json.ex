defmodule OwlGateWeb.Plugs.RequireReviewerJson do
  @moduledoc "Halts with 403 JSON unless the current user may review (manager/admin)."

  import Plug.Conn

  alias OwlGate.Policy.AccessPolicy

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns.current_user

    if AccessPolicy.can_review?(user) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Jason.encode!(%{error: "forbidden"}))
      |> halt()
    end
  end
end
