defmodule OwlGateWeb.UserRegistrationController do
  use OwlGateWeb, :controller

  alias OwlGate.Accounts
  alias OwlGateWeb.FormHelpers

  @session_key "current_user_id"

  def new(conn, _params) do
    render(conn, :new,
      csrf_token: Plug.CSRFProtection.get_csrf_token(),
      email: "",
      name: ""
    )
  end

  def create(conn, %{"user" => params}) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        conn
        |> put_session(@session_key, user.id)
        |> put_flash(:info, "Account created. You are signed in.")
        |> redirect(to: ~p"/dashboard")

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_flash(:error, FormHelpers.format_changeset_errors(cs))
        |> render(:new,
          csrf_token: Plug.CSRFProtection.get_csrf_token(),
          email: Map.get(params, "email", ""),
          name: Map.get(params, "name", "")
        )
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid form submission.")
    |> redirect(to: ~p"/register")
  end
end
