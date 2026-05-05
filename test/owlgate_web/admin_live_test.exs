defmodule OwlGateWeb.AdminLiveTest do
  use OwlGateWeb.ConnCase

  import OwlGate.Fixtures
  import Phoenix.LiveViewTest

  test "guest is redirected to login from admin users", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/users")
  end

  test "manager is redirected away from admin users", %{conn: conn} do
    %{manager: mgr} = seed_org()

    assert {:error, {:redirect, %{to: "/dashboard"}}} =
             conn
             |> log_in_user(mgr)
             |> live(~p"/admin/users")
  end

  test "admin sees admin users index", %{conn: conn} do
    %{owner: admin} = seed_org()

    {:ok, _lv, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/users")

    assert html =~ "Admin · Users"
  end

  test "POST /login signs in with fixture password", %{conn: conn} do
    %{manager: mgr} = seed_org()

    conn =
      post(conn, ~p"/login", %{
        "user" => %{"email" => mgr.email, "password" => "Password123!"}
      })

    assert redirected_to(conn) == "/dashboard"
  end
end
