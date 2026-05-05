defmodule OwlGateWeb.DevSessionController do
  @moduledoc "Development-only impersonation helpers for exercising operator LiveViews."

  use OwlGateWeb, :controller

  alias OwlGate.Accounts

  @session_key "current_user_id"

  def new(conn, _params) do
    render(conn, :new,
      csrf_token: Plug.CSRFProtection.get_csrf_token(),
      users: Accounts.list_users()
    )
  end

  def create(conn, %{"user_id" => user_id_param}) do
    case Integer.parse(to_string(user_id_param)) do
      {_id, _} = parsed ->
        do_create(conn, Accounts.get_user(elem(parsed, 0)))

      :error ->
        conn
        |> put_flash(:error, "Pick a valid user.")
        |> redirect(to: "/dev/session")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "User is required.")
    |> redirect(to: "/dev/session")
  end

  defp do_create(conn, nil) do
    conn
    |> put_flash(:error, "User not found.")
    |> redirect(to: "/dev/session")
  end

  defp do_create(conn, user) do
    conn
    |> put_session(@session_key, user.id)
    |> put_flash(:info, "Signed in as #{user.email}.")
    |> redirect(to: ~p"/dashboard")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: false)
    |> delete_session(@session_key)
    |> put_flash(:info, "Session cleared.")
    |> redirect(to: ~p"/")
  end
end
