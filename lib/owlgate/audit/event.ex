defmodule OwlGate.Audit.Event do
  @moduledoc """
  Immutable audit event for privileged lifecycle actions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OwlGate.Accounts.User

  schema "audit_events" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :integer
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime

    belongs_to :actor, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:action, :entity_type, :entity_id, :metadata, :occurred_at, :actor_id])
    |> validate_required([:action, :entity_type, :entity_id, :occurred_at, :actor_id])
    |> foreign_key_constraint(:actor_id)
  end
end
