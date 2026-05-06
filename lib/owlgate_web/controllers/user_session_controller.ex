defmodule OwlGateWeb.UserSessionController do
  use OwlGateWeb, :controller

  alias OwlGate.Accounts
  alias OwlGate.Accounts.User

  @session_key "current_user_id"

  def new(conn, _params) do
    render(conn, :new, csrf_token: Plug.CSRFProtection.get_csrf_token())
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    email = String.trim(to_string(email))
    password = String.trim(to_string(password))

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(@session_key, user.id)
        |> put_flash(:info, gettext("Welcome back."))
        |> redirect(to: redirect_path_for(user))

      {:error, :password_not_set} ->
        conn
        |> put_flash(
          :error,
          gettext("Password not set for this account. Ask an admin to set one.")
        )
        |> redirect(to: ~p"/login")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, gettext("Invalid email or password."))
        |> redirect(to: ~p"/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, gettext("Email and password are required."))
    |> redirect(to: ~p"/login")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: false)
    |> delete_session(@session_key)
    |> put_flash(:info, gettext("Signed out."))
    |> redirect(to: ~p"/")
  end

  defp redirect_path_for(%User{}), do: ~p"/dashboard"
end
