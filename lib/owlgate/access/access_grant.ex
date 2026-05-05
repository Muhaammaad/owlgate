defmodule OwlGate.Access.AccessGrant do
  @moduledoc """
  Provisioned access grant linked to an approved access request.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OwlGate.Access.Constants
  alias OwlGate.Accounts.User
  alias OwlGate.Access.{AccessRequest, Application}

  @statuses Constants.grant_statuses()

  schema "access_grants" do
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :external_ref, :string
    field :granted_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :lock_version, :integer, default: 1

    belongs_to :user, User
    belongs_to :application, Application
    belongs_to :granted_by, User
    belongs_to :access_request, AccessRequest

    timestamps(type: :utc_datetime)
  end

  def create_changeset(grant, attrs) do
    grant
    |> cast(attrs, [
      :user_id,
      :application_id,
      :granted_by_id,
      :access_request_id,
      :external_ref,
      :granted_at
    ])
    |> validate_required([
      :user_id,
      :application_id,
      :granted_by_id,
      :access_request_id,
      :granted_at
    ])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:application_id)
    |> foreign_key_constraint(:granted_by_id)
    |> foreign_key_constraint(:access_request_id)
    |> unique_constraint(:access_request_id)
    |> unique_constraint(:user_id, name: :access_grants_one_active_per_user_app_idx)
    |> check_constraint(:status, name: :access_grants_status_check)
    |> put_change(:status, :active)
  end

  def status_changeset(grant, attrs) do
    grant
    |> cast(attrs, [:status, :revoked_at])
    |> validate_required([:status])
    |> check_constraint(:status, name: :access_grants_status_check)
    |> check_constraint(:revoked_at, name: :access_grants_time_consistency_check)
    |> optimistic_lock(:lock_version)
  end
end
