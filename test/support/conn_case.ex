defmodule OwlGateWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use OwlGateWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  import Plug.Conn

  alias OwlGate.Accounts.User

  using do
    quote do
      # The default endpoint for testing
      @endpoint OwlGateWeb.Endpoint

      use OwlGateWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import OwlGateWeb.ConnCase
    end
  end

  @session_key "current_user_id"

  @doc """
  Puts `user.id` into the test session plug so LiveViews behave like signed-in browsers.
  """
  def log_in_user(conn, %User{id: id}) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> put_session(@session_key, id)
  end

  setup tags do
    OwlGate.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
