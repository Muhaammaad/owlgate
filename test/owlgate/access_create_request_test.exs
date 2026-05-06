defmodule OwlGate.AccessCreateRequestTest do
  use OwlGate.DataCase

  import OwlGate.Fixtures

  alias OwlGate.{Access, Accounts}
  alias OwlGate.Access.AccessRequest

  test "admin can create a request on behalf of another user" do
    %{owner: admin, employee: emp, app: app} = seed_org()

    assert {:ok, %AccessRequest{user_id: id}} =
             Access.create_request(admin, %{
               "subject_user_id" => "#{emp.id}",
               "application_id" => "#{app.id}",
               "reason" => "Admin provisioning path"
             })

    assert id == emp.id
  end

  test "admin without subject_user_id gets subject_user_required" do
    %{owner: admin, app: app} = seed_org()

    assert {:error, :subject_user_required} =
             Access.create_request(admin, %{
               "application_id" => "#{app.id}",
               "reason" => "Missing subject"
             })
  end

  test "employee cannot use subject_user_id to file for someone else" do
    %{owner: admin, employee: emp, app: app} = seed_org()

    assert {:ok, %AccessRequest{user_id: id}} =
             Access.create_request(emp, %{
               "subject_user_id" => "#{admin.id}",
               "application_id" => "#{app.id}",
               "reason" => "Trying to forge subject"
             })

    assert id == emp.id
  end

  test "list_grants/1 user_id option limits rows to that access holder" do
    %{manager: mgr, employee: emp, app: app} = seed_org()
    uniq = System.unique_integer([:positive])

    {:ok, peer} =
      Accounts.create_user(%{
        email: "peer#{uniq}@example.com",
        name: "Peer",
        role: :employee,
        manager_id: nil
      })

    _ = Accounts.set_password!(peer, "Password123!")

    assert {:ok, _} =
             Access.create_request(emp, %{
               "application_id" => app.id,
               "reason" => "Holder for grant filter test"
             })

    assert [req] = Access.list_access_requests(status: :pending)
    assert {:ok, _} = Access.approve_request(mgr, req.id)

    assert [_] = Access.list_grants(user_id: emp.id)
    assert [] == Access.list_grants(user_id: peer.id)
  end
end
