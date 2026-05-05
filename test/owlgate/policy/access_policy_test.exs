defmodule OwlGate.Policy.AccessPolicyTest do
  use ExUnit.Case, async: true

  alias OwlGate.Access.Application
  alias OwlGate.Accounts.User
  alias OwlGate.Policy.AccessPolicy

  doctest OwlGate.Policy.AccessPolicy

  test "only managers and admins can review requests" do
    assert AccessPolicy.can_review?(%User{role: :manager})
    assert AccessPolicy.can_review?(%User{role: :admin})
    refute AccessPolicy.can_review?(%User{role: :employee})
  end

  test "high risk review requires owner or admin" do
    app = %Application{risk_level: :high, owner_id: 7}

    assert AccessPolicy.can_review_high_risk?(%User{role: :admin}, app)
    assert AccessPolicy.can_review_high_risk?(%User{id: 7, role: :manager}, app)
    refute AccessPolicy.can_review_high_risk?(%User{id: 9, role: :manager}, app)
  end
end
