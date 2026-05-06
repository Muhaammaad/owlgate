defmodule OwlGateWeb.Api.AuditEventController do
  use OwlGateWeb, :controller

  alias OwlGate.Audit
  alias OwlGate.Audit.Event
  alias OwlGate.Policy.AccessPolicy

  def index(conn, params) do
    user = conn.assigns.current_user

    opts =
      [limit: parse_limit(Map.get(params, "limit"))]
      |> Keyword.merge(filter_opt(:action, Map.get(params, "action")))
      |> Keyword.merge(filter_opt(:entity_type, Map.get(params, "entity_type")))

    opts =
      if AccessPolicy.employee_data_scope?(user),
        do: Keyword.put(opts, :viewer_user_id, user.id),
        else: opts

    events = Audit.list_events(opts)
    json(conn, %{data: Enum.map(events, &serialize_event/1)})
  end

  defp parse_limit(nil), do: 200

  defp parse_limit(bin) when is_binary(bin) do
    case Integer.parse(String.trim(bin)) do
      {n, ""} -> min(max(n, 1), 500)
      _ -> 200
    end
  end

  defp parse_limit(_), do: 200

  defp filter_opt(_key, nil), do: []

  defp filter_opt(key, bin) when is_binary(bin) do
    case String.trim(bin) do
      "" -> []
      t -> [{key, t}]
    end
  end

  defp filter_opt(_, _), do: []

  defp serialize_event(%Event{} = e) do
    actor_email = e.actor && e.actor.email

    %{
      id: e.id,
      action: e.action,
      entity_type: e.entity_type,
      entity_id: e.entity_id,
      metadata: e.metadata,
      occurred_at: e.occurred_at,
      actor_id: e.actor_id,
      actor_email: actor_email
    }
  end
end
