defmodule OwlGate.Accounts do
  @moduledoc "Accounts context for actor lifecycle and role management."

  import Ecto.Query, warn: false

  alias OwlGate.Accounts.User
  alias OwlGate.Repo

  @doc "Lists all users."
  def list_users, do: Repo.all(User)

  @doc "Gets a user by id and raises if not found."
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Gets a user by id or returns nil."
  def get_user(id), do: Repo.get(User, id)

  @doc "Creates a user with role and ownership metadata."
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a user."
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a user."
  def delete_user(%User{} = user), do: Repo.delete(user)

  @doc "Returns a changeset for form usage."
  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)
end
