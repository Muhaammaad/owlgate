defmodule OwlGate.Accounts.User do
  @moduledoc """
  User schema for requesters, managers, and administrators.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @roles [:employee, :manager, :admin]
  @email_regex ~r/^[^\s]+@[^\s]+$/

  schema "users" do
    field :email, :string
    field :name, :string
    field :role, Ecto.Enum, values: @roles
    field :mfa_required, :boolean, default: false

    belongs_to :manager, __MODULE__
    has_many :managed_users, __MODULE__, foreign_key: :manager_id

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :mfa_required, :manager_id])
    |> validate_required([:email, :name, :role])
    |> update_change(:email, &String.downcase/1)
    |> validate_format(:email, @email_regex)
    |> unique_constraint(:email, name: :users_lower_email_idx)
    |> foreign_key_constraint(:manager_id)
  end
end
