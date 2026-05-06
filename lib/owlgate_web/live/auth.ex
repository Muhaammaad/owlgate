defmodule OwlGateWeb.Live.Auth do
  @moduledoc """
  LiveView session hooks for assigning the current user from the browser session.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: OwlGateWeb.Endpoint,
    router: OwlGateWeb.Router,
    statics: OwlGateWeb.static_paths()

  use Gettext, backend: OwlGateWeb.Gettext

  alias OwlGate.Accounts
  alias OwlGate.Policy.AdminPolicy

  def on_mount(:assign_current_user, _params, session, socket) do
    {:cont, assign(socket, :current_user, user_from_session(session))}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    case user_from_session(session) do
      nil ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, gettext("Sign in to continue."))
         |> redirect(to: ~p"/login")}

      %Accounts.User{} = user ->
        {:cont, assign(socket, :current_user, user)}
    end
  end

  def on_mount(:require_admin, _params, session, socket) do
    case user_from_session(session) do
      nil ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, gettext("Sign in to continue."))
         |> redirect(to: ~p"/login")}

      %Accounts.User{} = user ->
        if AdminPolicy.admin?(user) do
          {:cont, assign(socket, :current_user, user)}
        else
          {:halt,
           socket
           |> Phoenix.LiveView.put_flash(:error, gettext("Admins only."))
           |> redirect(to: ~p"/dashboard")}
        end
    end
  end

  defp user_from_session(session) do
    raw =
      case session do
        %{"current_user_id" => id} when not is_nil(id) -> id
        %{current_user_id: id} when not is_nil(id) -> id
        _ -> nil
      end

    case raw do
      nil -> nil
      id -> Accounts.get_user(id)
    end
  end
end
