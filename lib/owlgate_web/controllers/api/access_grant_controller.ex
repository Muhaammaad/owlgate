defmodule OwlGateWeb.Api.AccessGrantController do
  use OwlGateWeb, :controller

  alias OwlGate.Access
  alias OwlGate.Access.AccessGrant
  alias OwlGateWeb.Api.{JsonHelpers, Params}

  plug OwlGateWeb.Plugs.AuditRequestContext when action in [:revoke]

  def revoke(conn, %{"id" => raw_id}) do
    user = conn.assigns.current_user

    with {:ok, id} <- Params.parse_path_id(raw_id) do
      case Access.request_revoke(user, id) do
        {:ok, %AccessGrant{} = grant} ->
          json(conn, %{data: serialize_grant(grant)})

        {:error, reason} ->
          JsonHelpers.domain_error(conn, {:error, reason})
      end
    else
      :error ->
        JsonHelpers.invalid_path_id(conn)
    end
  end

  defp serialize_grant(%AccessGrant{} = g) do
    %{
      id: g.id,
      status: g.status,
      application_id: g.application_id,
      user_id: g.user_id,
      access_request_id: g.access_request_id,
      granted_by_id: g.granted_by_id,
      external_ref: g.external_ref,
      granted_at: g.granted_at,
      revoked_at: g.revoked_at,
      inserted_at: g.inserted_at,
      updated_at: g.updated_at
    }
  end
end
