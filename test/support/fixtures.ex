defmodule OwlGate.Fixtures do
  @moduledoc false

  alias OwlGate.{Accounts, Access}

  @doc "Inserts distinct admin owner, manager, employee, and a low-risk application owned by admin."
  def seed_org(opts \\ []) do
    uniq = Keyword.get_lazy(opts, :uniq, fn -> System.unique_integer([:positive]) end)

    {:ok, owner} =
      Accounts.create_user(%{
        email: "owner#{uniq}@example.com",
        name: "Owner",
        role: :admin,
        manager_id: nil
      })

    {:ok, manager} =
      Accounts.create_user(%{
        email: "mgr#{uniq}@example.com",
        name: "Mgr",
        role: :manager,
        manager_id: nil
      })

    {:ok, employee} =
      Accounts.create_user(%{
        email: "emp#{uniq}@example.com",
        name: "Emp",
        role: :employee,
        manager_id: nil
      })

    pw = Keyword.get(opts, :password, "Password123!")
    _ = Accounts.set_password!(owner, pw)
    _ = Accounts.set_password!(manager, pw)
    _ = Accounts.set_password!(employee, pw)

    slug = Keyword.get(opts, :slug, "app-#{uniq}")

    {:ok, app} =
      Access.create_application(%{
        name: "Fixture App #{uniq}",
        slug: slug,
        risk_level: :low,
        owner_id: owner.id,
        active: true
      })

    %{owner: owner, manager: manager, employee: employee, app: app, uniq: uniq}
  end
end
