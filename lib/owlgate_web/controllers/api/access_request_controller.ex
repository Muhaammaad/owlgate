defmodule OwlGateWeb.Api.AccessRequestController do
  use OwlGateWeb, :controller

  alias OwlGate.Access
  alias OwlGate.Access.AccessRequest
  alias OwlGateWeb.Api.{JsonHelpers, Params}

  plug OwlGateWeb.Plugs.RateLimitApi when action in [:create]
  plug OwlGateWeb.Plugs.AuditRequestContext when action in [:create, :approve, :deny]

  def create(conn, params) do
    user = conn.assigns.current_user

    payload =
      case Map.get(params, "access_request") do
        %{} = inner -> inner
        _ -> params
      end

    attrs =
      payload
      |> Map.take(["application_id", "reason", "subject_user_id"])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Access.create_request(user, attrs) do
      {:ok, %AccessRequest{} = req} ->
        conn
        |> put_status(:created)
        |> json(%{data: serialize_request(req)})

      {:error, reason} ->
        JsonHelpers.domain_error(conn, {:error, reason})
    end
  end

  def approve(conn, %{"id" => raw_id}) do
    user = conn.assigns.current_user

    with {:ok, id} <- Params.parse_path_id(raw_id) do
      case Access.approve_request(user, id) do
        {:ok, %AccessRequest{} = req} ->
          json(conn, %{data: serialize_request(req)})

        {:error, reason} ->
          JsonHelpers.domain_error(conn, {:error, reason})
      end
    else
      :error ->
        JsonHelpers.invalid_path_id(conn)
    end
  end

  def deny(conn, %{"id" => raw_id}) do
    user = conn.assigns.current_user
    reason = extract_reason(conn)

    with {:ok, id} <- Params.parse_path_id(raw_id) do
      case Access.deny_request(user, id, reason) do
        {:ok, %AccessRequest{} = req} ->
          json(conn, %{data: serialize_request(req)})

        {:error, reason} ->
          JsonHelpers.domain_error(conn, {:error, reason})
      end
    else
      :error ->
        JsonHelpers.invalid_path_id(conn)
    end
  end

  defp extract_reason(conn) do
    params = conn.body_params || %{}

    case Map.get(params, "reason") do
      nil -> Map.get(params, :reason)
      other -> other
    end
  end

  defp serialize_request(%AccessRequest{} = r) do
    %{
      id: r.id,
      status: r.status,
      reason: r.reason,
      denial_reason: r.denial_reason,
      application_id: r.application_id,
      user_id: r.user_id,
      reviewed_by_id: r.reviewed_by_id,
      reviewed_at: r.reviewed_at,
      inserted_at: r.inserted_at,
      updated_at: r.updated_at
    }
  end
end
