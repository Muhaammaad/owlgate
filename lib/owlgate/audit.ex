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
  """
  def list_events(opts \\ []) do
    Event
    |> maybe_filter_actor(opts[:actor_id])
    |> maybe_filter_action(opts[:action])
    |> order_by(desc: :occurred_at)
    |> Repo.all()
  end

  defp maybe_filter_actor(query, nil), do: query
  defp maybe_filter_actor(query, actor_id), do: where(query, [e], e.actor_id == ^actor_id)

  defp maybe_filter_action(query, nil), do: query
  defp maybe_filter_action(query, action), do: where(query, [e], e.action == ^action)
end
