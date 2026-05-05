defmodule OwlGate.AccessDashboardTest do
  use OwlGate.DataCase

  import OwlGate.Fixtures

  alias OwlGate.Access
  alias OwlGate.Access.Constants

  test "dashboard_snapshot includes every request and grant status key" do
    snap = Access.dashboard_snapshot()

    assert Enum.sort(Map.keys(snap.requests)) == Enum.sort(Constants.request_statuses())
    assert Enum.sort(Map.keys(snap.grants)) == Enum.sort(Constants.grant_statuses())
    assert Enum.all?(snap.requests, fn {_k, count} -> count == 0 end)
  end

  test "dashboard_snapshot counts a pending request after create_request" do
    %{employee: employee, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(employee, %{
        "application_id" => app.id,
        "reason" => "Need access for onboarding"
      })

    snap = Access.dashboard_snapshot()

    assert snap.requests[:pending] == 1
    assert snap.requests[:approved] == 0
    assert snap.requests[:provisioned] == 0
  end
end
