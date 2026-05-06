defmodule OwlGateWeb.UserRegistrationControllerTest do
  use OwlGateWeb.ConnCase, async: true

  alias OwlGate.Accounts

  test "duplicate email does not crash and returns validation error", %{conn: conn} do
    email = "duplicate@example.com"

    assert {:ok, _user} =
             Accounts.register_user(%{
               "email" => email,
               "name" => "Existing User",
               "password" => "Password123!",
               "role" => "employee"
             })

    conn =
      post(conn, ~p"/register", %{
        "user" => %{
          "email" => email,
          "name" => "Another User",
          "password" => "Password123!",
          "role" => "employee"
        }
      })

    assert html_response(conn, 200) =~ "email: has already been taken"
  end
end
