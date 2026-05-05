defmodule OwlGate.Audit do
  @moduledoc "Audit event logging and querying."

  import Ecto.Query, warn: false

  alias OwlGate.Audit.Event
  alias OwlGate.Repo

  @doc """
  Writes an immutable audit event for lifecycle actions.
  """
  def log(actor_id, action, entity_type, entity_id, metadata \\ %{}) do
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

  Supports `:limit` (default 200) and preloads `:actor` for UI display.
  """
  def list_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)

    Event
    |> maybe_filter_actor(Keyword.get(opts, :actor_id))
    |> maybe_filter_action(Keyword.get(opts, :action))
    |> maybe_filter_entity_type(Keyword.get(opts, :entity_type))
    |> order_by(desc: :occurred_at)
    |> limit(^limit)
    |> preload([:actor])
    |> Repo.all()
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
