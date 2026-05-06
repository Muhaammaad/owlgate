defmodule OwlGate.Audit do
  @moduledoc "Audit event logging and querying."

  import Ecto.Query, warn: false

  alias OwlGate.Access.{AccessGrant, AccessRequest, Constants}
  alias OwlGate.Audit.{Event, RequestContext}
  alias OwlGate.Repo

  @doc """
  Writes an immutable audit event for lifecycle actions.

  When `OwlGateWeb.Plugs.AuditRequestContext` ran for the same request, its
  fields (e.g. `client_ip`, `user_agent`) are merged into `metadata` unless
  the caller already set those keys.
  """
  def log(actor_id, action, entity_type, entity_id, metadata \\ %{}) do
    metadata =
      case RequestContext.peek() do
        nil -> metadata
        ctx -> Map.merge(ctx, metadata)
      end

    attrs = %{
      actor_id: actor_id,
      action: action,
      entity_type: entity_type,
      entity_id: entity_id,
      metadata: metadata,
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit events with optional actor/action filters.

  Supports `:limit` (default 200), `:viewer_user_id` (employees only — limits to
  events they acted in or that reference their access requests / grants),
  and preloads `:actor` for UI display.
  """
  def list_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)

    Event
    |> maybe_scope_for_viewer(Keyword.get(opts, :viewer_user_id))
    |> maybe_filter_actor(Keyword.get(opts, :actor_id))
    |> maybe_filter_action(Keyword.get(opts, :action))
    |> maybe_filter_entity_type(Keyword.get(opts, :entity_type))
    |> order_by(desc: :occurred_at)
    |> limit(^limit)
    |> preload([:actor])
    |> Repo.all()
  end

  defp maybe_scope_for_viewer(query, nil), do: query

  defp maybe_scope_for_viewer(query, viewer_id) when is_integer(viewer_id) do
    req_ids =
      from r in AccessRequest,
        where: r.user_id == ^viewer_id,
        select: r.id

    grant_ids =
      from g in AccessGrant,
        where: g.user_id == ^viewer_id,
        select: g.id

    et_req = Constants.entity_access_request()
    et_grant = Constants.entity_access_grant()

    where(
      query,
      [e],
      e.actor_id == ^viewer_id or
        (e.entity_type == ^et_req and e.entity_id in subquery(req_ids)) or
        (e.entity_type == ^et_grant and e.entity_id in subquery(grant_ids))
    )
  end

  defp maybe_filter_actor(query, nil), do: query
  defp maybe_filter_actor(query, actor_id), do: where(query, [e], e.actor_id == ^actor_id)

  defp maybe_filter_action(query, nil), do: query
  defp maybe_filter_action(query, ""), do: query
  defp maybe_filter_action(query, action), do: where(query, [e], e.action == ^action)

  defp maybe_filter_entity_type(query, nil), do: query
  defp maybe_filter_entity_type(query, ""), do: query

  defp maybe_filter_entity_type(query, entity_type),
    do: where(query, [e], e.entity_type == ^entity_type)
end
