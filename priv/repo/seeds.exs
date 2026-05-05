# Seeds OwlGate with demo users and one application (idempotent).
#
# Run after migrate:
#   mix run priv/repo/seeds.exs
#
# Or full setup (create DB, migrate, seed):
#   mix ecto.setup

import Ecto.Query

alias OwlGate.{Accounts, Access, Repo}
alias OwlGate.Accounts.User

defmodule OwlGate.Seeds do
  @moduledoc false

  def run do
    Repo.transaction(fn ->
      admin = ensure_user!("admin@owlgate.local", %{name: "Alex Admin", role: :admin})
      manager = ensure_user!("manager@owlgate.local", %{name: "Morgan Manager", role: :manager})
      employee = ensure_user!("employee@owlgate.local", %{name: "Ed Employee", role: :employee})

      ensure_application!("demo-portal", %{
        name: "Demo Portal",
        slug: "demo-portal",
        risk_level: :medium,
        owner_id: admin.id,
        active: true,
        requires_mfa: false
      })

      IO.puts("""
      Seed complete.

      Users (sign in via Dev session at /dev/session when dev_routes is enabled):
        admin@owlgate.local     (#{admin.id}) — admin
        manager@owlgate.local   (#{manager.id}) — manager
        employee@owlgate.local  (#{employee.id}) — employee

      Application: demo-portal (owner: admin)

      Next: visit http://localhost:4000 → Dashboard / Access requests, or /dev/session to impersonate.
      """)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> IO.puts(:stderr, "Seed failed: #{inspect(reason)}")
    end
  end

  defp ensure_user!(email, attrs) do
    normalized = String.downcase(email)

    case Repo.get_by(User, email: normalized) do
      %User{} = user ->
        user

      nil ->
        {:ok, user} =
          Accounts.create_user(Map.merge(attrs, %{email: normalized, manager_id: nil}))

        user
    end
  end

  defp ensure_application!(slug, attrs) do
    case Repo.one(from(a in OwlGate.Access.Application, where: a.slug == ^slug, select: a.id)) do
      nil ->
        {:ok, app} = Access.create_application(attrs)
        app

      _id ->
        # Already exists; skip (avoid duplicate slug)
        Repo.one!(from(a in OwlGate.Access.Application, where: a.slug == ^slug))
    end
  end
end

OwlGate.Seeds.run()
