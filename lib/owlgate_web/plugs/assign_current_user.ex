defmodule OwlGateWeb.Plugs.AssignCurrentUser do
  @moduledoc """
  Loads `conn.assigns[:current_user]` from the signed session key `current_user_id`.
  """

  import Plug.Conn

  alias OwlGate.Accounts

  @session_key "current_user_id"

  def init(opts), do: opts

  def call(conn, _opts) do
    id = get_session(conn, @session_key)
    assign(conn, :current_user, if(id, do: Accounts.get_user(id), else: nil))
  end
end
