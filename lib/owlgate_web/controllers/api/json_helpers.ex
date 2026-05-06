defmodule OwlGateWeb.Api.JsonHelpers do
  @moduledoc false

  import Plug.Conn, only: [put_status: 2]
  import Phoenix.Controller, only: [json: 2]

  @spec domain_error(Plug.Conn.t(), {:error, term()}) :: Plug.Conn.t()
  def domain_error(conn, {:error, reason}) do
    {status, body} = map_reason(reason)
    conn |> put_status(status) |> json(body)
  end

  @doc "400 JSON response for malformed numeric IDs in path segments."
  @spec invalid_path_id(Plug.Conn.t()) :: Plug.Conn.t()
  def invalid_path_id(conn) do
    conn |> put_status(:bad_request) |> json(%{error: "invalid_id"})
  end

  defp map_reason(:not_found), do: {:not_found, %{error: "not_found"}}
  defp map_reason(:forbidden), do: {:forbidden, %{error: "forbidden"}}
  defp map_reason(:invalid_status), do: {:unprocessable_entity, %{error: "invalid_status"}}
  defp map_reason(:duplicate_request), do: {:conflict, %{error: "duplicate_request"}}

  defp map_reason(:already_has_active_grant),
    do: {:conflict, %{error: "already_has_active_grant"}}

  defp map_reason(:self_approval_not_allowed),
    do: {:forbidden, %{error: "self_approval_not_allowed"}}

  defp map_reason(:high_risk_requires_owner_or_admin),
    do: {:forbidden, %{error: "high_risk_requires_owner_or_admin"}}

  defp map_reason(:inactive_application),
    do: {:unprocessable_entity, %{error: "inactive_application"}}

  defp map_reason(:denial_reason_required),
    do: {:unprocessable_entity, %{error: "denial_reason_required"}}

  defp map_reason(:subject_user_required),
    do: {:unprocessable_entity, %{error: "subject_user_required"}}

  defp map_reason(:subject_user_not_found), do: {:not_found, %{error: "subject_user_not_found"}}

  defp map_reason(other),
    do: {:bad_gateway, %{error: "unexpected", detail: inspect(other)}}
end
