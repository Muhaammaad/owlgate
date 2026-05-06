defmodule OwlGate.Accounts do
  @moduledoc "Accounts context for actor lifecycle and role management."

  import Ecto.Query, warn: false

  alias OwlGate.Accounts.User
  alias OwlGate.Repo

  @doc "Users with manager role (optional assignment as someone's manager)."
  def list_managers do
    User
    |> where([u], u.role == :manager)
    |> order_by([u], asc: u.email)
    |> Repo.all()
  end

  @doc "Users who may own an application (admins and managers)."
  def list_owner_candidates do
    User
    |> where([u], u.role in [:admin, :manager])
    |> order_by([u], asc: u.email)
    |> Repo.all()
  end

  @doc "Lists all users ordered by email."
  def list_users(opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    User
    |> order_by([u], asc: u.email)
    |> preload(^preload)
    |> Repo.all()
  end

  @doc "Gets a user by id and raises if not found."
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Gets a user by id or returns nil."
  def get_user(id), do: Repo.get(User, id)

  @doc "Looks up a user by email (case-insensitive stored)."
  def get_user_by_email(email) when is_binary(email) do
    email = String.downcase(String.trim(email))
    Repo.get_by(User, email: email)
  end

  @doc """
  Authenticates by email and password.

  Returns `{:error, :invalid_credentials}` for unknown users or wrong passwords,
  and `{:error, :password_not_set}` when the account exists but has no password hash yet.
  """
  def authenticate_user(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user == nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user.password_hash == nil ->
        {:error, :password_not_set}

      User.valid_password?(user, password) ->
        {:ok, user}

      true ->
        {:error, :invalid_credentials}
    end
  end

  @doc "Registers a new user (first account becomes admin)."
  def register_user(attrs) do
    %User{}
    |> User.register_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Changeset for the registration HTML form."
  def change_registration(attrs \\ %{}) do
    User.registration_form_changeset(%User{}, attrs)
  end

  @doc "Creates a user without password (legacy / seeds); prefer create_user_with_password/1."
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Admin-only user creation with password."
  def create_user_with_password(attrs) do
    %User{}
    |> User.admin_create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Admin-only user update."
  def update_user_managed(%User{} = user, attrs) do
    user
    |> User.admin_update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Updates a user via generic changeset (no password handling)."
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a user."
  def delete_user(%User{} = user), do: Repo.delete(user)

  @doc "Returns a changeset for form usage."
  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  @doc "Changeset for admin create/edit forms."
  def change_user_admin(%User{} = user, attrs \\ %{}) do
    User.admin_update_changeset(user, attrs)
  end

  def change_user_admin_create(attrs \\ %{}) do
    User.admin_form_changeset(%User{role: :employee}, attrs)
  end

  @doc "Persist a new bcrypt hash for the user (seeds, migrations)."
  def set_password!(%User{} = user, password) when is_binary(password) do
    user
    |> User.password_set_changeset(password)
    |> Repo.update!()
  end
end
