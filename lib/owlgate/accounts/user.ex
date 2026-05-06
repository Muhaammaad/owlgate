defmodule OwlGate.Accounts.User do
  @moduledoc """
  User schema for requesters, managers, and administrators.

  Password hashes use bcrypt (`password_hash`). Legacy rows without a hash cannot sign in
  until an admin sets a password or the user registers.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OwlGate.Repo

  @roles [:employee, :manager, :admin]
  @email_regex ~r/^[^\s]+@[^\s]+$/

  schema "users" do
    field :email, :string
    field :name, :string
    field :role, Ecto.Enum, values: @roles
    field :mfa_required, :boolean, default: false
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true

    belongs_to :manager, __MODULE__
    has_many :managed_users, __MODULE__, foreign_key: :manager_id

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :mfa_required, :manager_id])
    |> validate_required([:email, :name, :role])
    |> validate_email_and_manager()
  end

  @doc "Empty or repopulated registration form (no insert validations yet)."
  def registration_form_changeset(user \\ %__MODULE__{}, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> update_change(:email, fn e ->
      if is_binary(e), do: String.downcase(String.trim(e)), else: e
    end)
  end

  @doc "Public self-registration insert changeset. First user becomes admin."
  def register_changeset(user, attrs) do
    user
    |> registration_form_changeset(attrs)
    |> validate_required([:email, :name, :password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_email_and_manager()
    |> put_change(:role, registration_role())
    |> put_change(:manager_id, nil)
    |> put_change(:mfa_required, false)
    |> hash_password()
  end

  defp registration_role do
    case Repo.aggregate(__MODULE__, :count, :id) do
      0 -> :admin
      _ -> :employee
    end
  end

  @doc "Admin HTML form (cast only, no insert validations)."
  def admin_form_changeset(user, attrs \\ %{}) do
    cast(user, attrs, [:email, :name, :role, :manager_id, :mfa_required, :password])
  end

  @doc "Admin-managed create with optional manager link."
  def admin_create_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :manager_id, :mfa_required, :password])
    |> validate_required([:email, :name, :role, :password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_email_and_manager()
    |> hash_password()
  end

  @doc "Admin-managed update; password optional (leave blank to keep)."
  def admin_update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :manager_id, :mfa_required, :password])
    |> validate_required([:email, :name, :role])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_email_and_manager()
    |> maybe_hash_password()
  end

  defp validate_email_and_manager(changeset) do
    changeset
    |> update_change(:email, &String.downcase/1)
    |> validate_format(:email, @email_regex)
    |> unique_constraint(:email, name: :users_lower_email_idx)
    |> foreign_key_constraint(:manager_id)
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        add_error(changeset, :password, "can't be blank")

      "" ->
        add_error(changeset, :password, "can't be blank")

      password ->
        changeset
        |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end

  @doc "Sets or replaces password (e.g. seeds)."
  def password_set_changeset(user, password) when is_binary(password) do
    user
    |> cast(%{password: password}, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> hash_password()
  end

  defp maybe_hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      "" ->
        delete_change(changeset, :password)

      password ->
        changeset
        |> validate_length(:password, min: 8, max: 72)
        |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end

  def valid_password?(%__MODULE__{password_hash: hash}, password)
      when is_binary(hash) and is_binary(password) and password != "" do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
