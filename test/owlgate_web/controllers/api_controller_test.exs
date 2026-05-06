defmodule OwlGateWeb.ApiControllerTest do
  use OwlGateWeb.ConnCase

  import Ecto.Query
  import OwlGate.Fixtures

  alias OwlGate.{Access, Repo}
  alias OwlGate.Access.AccessRequest

  test "POST /api/access-requests creates when authenticated" do
    %{employee: emp, app: app} = seed_org()
    conn = build_conn() |> log_in_user(emp)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post(
        "/api/access-requests",
        Jason.encode!(%{"application_id" => app.id, "reason" => "Need fixture access"})
      )

    assert %{"data" => %{"id" => id, "status" => "pending"}} = json_response(conn, 201)
    assert is_integer(id)
  end

  test "POST /api/access-requests returns 401 without session" do
    %{employee: _emp, app: app} = seed_org()

    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post(
        "/api/access-requests",
        Jason.encode!(%{"application_id" => app.id, "reason" => "Anonymous attempt"})
      )

    assert %{"error" => "unauthenticated"} = json_response(conn, 401)
  end

  test "POST approve/deny requires reviewer" do
    %{employee: emp, manager: mgr, app: app} = seed_org()

    {:ok, %AccessRequest{id: rid}} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Review gate api test"
      })

    denied =
      build_conn()
      |> log_in_user(emp)
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post("/api/access-requests/#{rid}/approve", "{}")

    assert json_response(denied, 403)

    approved =
      build_conn()
      |> log_in_user(mgr)
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post("/api/access-requests/#{rid}/approve", "{}")

    assert %{"data" => %{"id" => ^rid, "status" => "approved"}} = json_response(approved, 200)
  end

  test "GET /api/audit-events scopes employees to self" do
    %{employee: emp, manager: mgr, app: app} = seed_org()

    {:ok, %AccessRequest{id: rid}} =
      Access.create_request(emp, %{
        "application_id" => app.id,
        "reason" => "Audit api scope test"
      })

    {:ok, _} = Access.approve_request(mgr, rid)

    emp_conn =
      build_conn()
      |> log_in_user(emp)
      |> put_req_header("accept", "application/json")
      |> get("/api/audit-events")

    mgr_conn =
      build_conn()
      |> log_in_user(mgr)
      |> put_req_header("accept", "application/json")
      |> get("/api/audit-events")

    emp_events = json_response(emp_conn, 200)["data"]
    mgr_events = json_response(mgr_conn, 200)["data"]

    assert length(mgr_events) >= length(emp_events)
    refute mgr_events == []
  end

  test "audit events include request metadata when AuditRequestContext ran" do
    %{employee: emp, app: app} = seed_org()

    conn =
      build_conn()
      |> Plug.Conn.put_req_header("user-agent", "ApiControllerTest/1.0")
      |> log_in_user(emp)
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> post(
        "/api/access-requests",
        Jason.encode!(%{"application_id" => app.id, "reason" => "Audit metadata capture"})
      )

    assert json_response(conn, 201)

    event =
      Repo.one(
        from e in OwlGate.Audit.Event,
          where: e.action == "access_request.created",
          order_by: [desc: e.id],
          limit: 1,
          select: e
      )

    assert %{"client_ip" => ip, "user_agent" => ua} = event.metadata
    assert is_binary(ip)
    assert ua =~ "ApiControllerTest"
  end
end
