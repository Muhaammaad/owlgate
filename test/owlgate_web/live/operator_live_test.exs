defmodule OwlGateWeb.OperatorLiveTest do
  use OwlGateWeb.ConnCase

  import OwlGate.Fixtures
  import Phoenix.LiveViewTest

  alias OwlGate.Access
  alias OwlGate.Access.AccessGrant
  alias OwlGate.Repo

  test "guest is redirected away from dashboard", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
  end

  test "guest is redirected away from grants and audit", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/grants")
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/audit-events")
  end

  test "signed-in manager sees dashboard with pending count", %{conn: conn} do
    %{manager: mgr, employee: emp, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Need access soon"
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(mgr)
      |> live(~p"/dashboard")

    assert html =~ "Operator dashboard"
    assert html =~ "pending"
  end

  test "approve from show runs inline provisioning job to provisioned", %{conn: conn} do
    %{manager: mgr, employee: emp, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Need access for rollout"
      })

    assert [req] = Access.list_access_requests(status: :pending)

    conn = log_in_user(conn, mgr)
    {:ok, lv, _} = live(conn, ~p"/access-requests/#{req.id}")
    assert render(lv) =~ req.application.slug

    assert lv |> has_element?(~s(button[phx-click="approve"]))

    lv
    |> element(~s(button[phx-click="approve"]))
    |> render_click()

    assert %AccessGrant{} = Repo.get_by!(AccessGrant, access_request_id: req.id)

    assert %OwlGate.Access.AccessRequest{status: :provisioned} =
             Repo.get!(OwlGate.Access.AccessRequest, req.id)
  end

  test "manager queues revoke from grants list; job completes revoked", %{conn: conn} do
    %{manager: mgr, employee: emp, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Needs access before revoke test"
      })

    assert [req] = Access.list_access_requests(status: :pending)

    conn = log_in_user(conn, mgr)

    {:ok, lv, _} = live(conn, ~p"/access-requests/#{req.id}")

    lv
    |> element(~s(button[phx-click="approve"]))
    |> render_click()

    grant = Repo.get_by!(AccessGrant, access_request_id: req.id)
    assert grant.status == :active

    {:ok, lv2, _} = live(conn, ~p"/grants")
    assert render(lv2) =~ "Queue revoke"

    lv2
    |> element("button", "Queue revoke")
    |> render_click()

    assert %AccessGrant{status: :revoked} = Repo.get!(AccessGrant, grant.id)
  end

  test "audit feed lists events after provisioning", %{conn: conn} do
    %{manager: mgr, employee: emp, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Needs access for audit test"
      })

    assert [req] = Access.list_access_requests(status: :pending)

    conn = log_in_user(conn, mgr)
    {:ok, lv, _} = live(conn, ~p"/access-requests/#{req.id}")

    lv
    |> element(~s(button[phx-click="approve"]))
    |> render_click()

    {:ok, _lv_audit, html} =
      conn
      |> live(~p"/audit-events")

    assert html =~ "Audit events"
    assert html =~ "access_grant.activated" or html =~ "access_request.approved"
  end

  test "requester cannot self-approve from the LiveView UI", %{conn: conn} do
    %{employee: emp, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Need access badly"
      })

    assert [req] = Access.list_access_requests(status: :pending)

    {:ok, lv, _} =
      conn
      |> log_in_user(emp)
      |> live(~p"/access-requests/#{req.id}")

    refute has_element?(lv, ~s(button[phx-click="approve"]))
  end

  test "deny persists denial reason visible on show page", %{conn: conn} do
    %{manager: mgr, employee: emp, app: app} = seed_org()

    {:ok, _} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Please grant temp access"
      })

    assert [req] = Access.list_access_requests(status: :pending)

    {:ok, lv, _} =
      conn
      |> log_in_user(mgr)
      |> live(~p"/access-requests/#{req.id}")

    lv
    |> form("#deny-request", %{reason: "Policy review not complete"})
    |> render_submit()

    assert %OwlGate.Access.AccessRequest{status: :denied, denial_reason: reason} =
             Repo.get!(OwlGate.Access.AccessRequest, req.id)

    assert reason =~ "Policy review"

    {:ok, lv2, _} =
      conn
      |> log_in_user(mgr)
      |> live(~p"/access-requests/#{req.id}")

    assert render(lv2) =~ "Policy review"
  end
end
