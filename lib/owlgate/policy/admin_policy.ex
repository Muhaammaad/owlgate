defmodule OwlGate.Policy.AdminPolicy do
  @moduledoc "Authorization helpers for admin-only surfaces."

  alias OwlGate.Accounts.User

  def admin?(%User{role: :admin}), do: true
  def admin?(_), do: false
end
