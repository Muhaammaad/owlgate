defmodule OwlGateWeb.UserSessionController do
  use OwlGateWeb, :controller

  alias OwlGate.Accounts

  @session_key "current_user_id"

  def new(conn, _params) do
    render(conn, :new, csrf_token: Plug.CSRFProtection.get_csrf_token())
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    email = String.trim(to_string(email))
    password = to_string(password)

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(@session_key, user.id)
        |> put_flash(:info, "Welcome back.")
        |> redirect(to: ~p"/dashboard")

      {:error, :password_not_set} ->
        conn
        |> put_flash(:error, "Password not set for this account. Ask an admin to set one.")
        |> redirect(to: ~p"/login")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Email and password are required.")
    |> redirect(to: ~p"/login")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: false)
    |> delete_session(@session_key)
    |> put_flash(:info, "Signed out.")
    |> redirect(to: ~p"/")
  end
end
