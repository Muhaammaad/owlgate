defmodule OwlGateWeb.PageControllerTest do
  use OwlGateWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "OwlGate"
    assert html =~ "Access governance"
  end
end
