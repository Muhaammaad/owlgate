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

  test "list_access_requests search filters by requester email substring" do
    %{employee: emp, app: app} = seed_org()

    assert {:ok, _} =
             Access.create_request(emp, %{
               "application_id" => app.id,
               "reason" => "Search filter test"
             })

    [local, _domain] = String.split(emp.email, "@")
    q = String.slice(local, 0, max(1, min(4, String.length(local))))

    assert [_] = Access.list_access_requests(search: q)
    assert [] == Access.list_access_requests(search: "zzzznotfound9999")
  end

  test "list_access_requests search matches application slug, application name, and request id" do
    %{employee: emp, app: app} = seed_org()

    assert {:ok, req} =
             Access.create_request(emp, %{
               "application_id" => app.id,
               "reason" => "Search across related fields"
             })

    assert Enum.any?(Access.list_access_requests(search: app.slug), &(&1.id == req.id))
    assert Enum.any?(Access.list_access_requests(search: app.name), &(&1.id == req.id))

    assert Enum.any?(
             Access.list_access_requests(search: Integer.to_string(req.id)),
             &(&1.id == req.id)
           )
  end
end
