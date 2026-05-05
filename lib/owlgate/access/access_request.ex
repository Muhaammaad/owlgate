defmodule OwlGate.Access.AccessRequest do
  @moduledoc """
  Access request entity that drives review and provisioning lifecycle.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OwlGate.Access.Constants
  alias OwlGate.Accounts.User
  alias OwlGate.Access.Application

  @statuses Constants.request_statuses()

  schema "access_requests" do
    field :reason, :string
    field :denial_reason, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :expires_at, :utc_datetime
    field :reviewed_at, :utc_datetime
    field :request_token, Ecto.UUID
    field :lock_version, :integer, default: 1

    belongs_to :user, User
    belongs_to :application, Application
    belongs_to :reviewed_by, User

    timestamps(type: :utc_datetime)
  end

  def create_changeset(access_request, attrs) do
    access_request
    |> cast(attrs, [:user_id, :application_id, :reason, :expires_at, :request_token])
    |> validate_required([:user_id, :application_id, :reason, :request_token])
    |> validate_length(:reason, min: 5)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:application_id)
    |> unique_constraint(:request_token)
    |> unique_constraint(:user_id, name: :access_requests_one_open_per_user_app_idx)
    |> check_constraint(:status, name: :access_requests_status_check)
    |> put_change(:status, :pending)
  end

  def review_changeset(access_request, attrs) do
    access_request
    |> cast(attrs, [:status, :reviewed_by_id, :reviewed_at, :denial_reason])
    |> validate_required([:status, :reviewed_by_id, :reviewed_at])
    |> validate_denial_reason()
    |> foreign_key_constraint(:reviewed_by_id)
    |> check_constraint(:status, name: :access_requests_status_check)
    |> check_constraint(:reviewed_by_id, name: :access_requests_reviewed_fields_check)
    |> check_constraint(:denial_reason, name: :access_requests_denial_reason_check)
    |> optimistic_lock(:lock_version)
  end

  def status_changeset(access_request, attrs) do
    access_request
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> check_constraint(:status, name: :access_requests_status_check)
    |> optimistic_lock(:lock_version)
  end

  defp validate_denial_reason(changeset) do
    case get_field(changeset, :status) do
      :denied ->
        changeset
        |> validate_required([:denial_reason])
        |> validate_length(:denial_reason, min: 3)

      _ ->
        put_change(changeset, :denial_reason, nil)
    end
  end
end
