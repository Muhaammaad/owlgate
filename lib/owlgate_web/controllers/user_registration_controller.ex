defmodule OwlGateWeb.UserRegistrationController do
  use OwlGateWeb, :controller

  alias OwlGate.Accounts
  alias OwlGate.Accounts.User
  alias OwlGateWeb.FormHelpers

  @session_key "current_user_id"

  def new(conn, _params) do
    render(conn, :new,
      csrf_token: Plug.CSRFProtection.get_csrf_token(),
      email: "",
      name: "",
      role: "employee"
    )
  end

  def create(conn, %{"user" => params}) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        conn
        |> put_session(@session_key, user.id)
        |> put_flash(:info, "Account created. You are signed in.")
        |> redirect(to: redirect_path_for(user))

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_flash(:error, FormHelpers.format_changeset_errors(cs))
        |> render(:new,
          csrf_token: Plug.CSRFProtection.get_csrf_token(),
          email: Map.get(params, "email", ""),
          name: Map.get(params, "name", ""),
          role: Map.get(params, "role", "employee")
        )
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid form submission.")
    |> redirect(to: ~p"/register")
  end

  defp redirect_path_for(%User{role: :admin}), do: ~p"/admin/users"
  defp redirect_path_for(%User{}), do: ~p"/dashboard"
end
