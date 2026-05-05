defmodule OwlGateWeb.DashboardLive do
  @moduledoc "Operator dashboard with access request and grant counts."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Constants

  on_mount {OwlGateWeb.Live.Auth, :require_authenticated_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_snapshot(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign_snapshot(socket)}
  end

  defp assign_snapshot(socket) do
    snap = Access.dashboard_snapshot()

    request_rows =
      Enum.map(Constants.request_statuses(), fn status ->
        {status, Map.fetch!(snap.requests, status)}
      end)

    grant_rows =
      Enum.map(Constants.grant_statuses(), fn status ->
        {status, Map.fetch!(snap.grants, status)}
      end)

    socket
    |> assign(:snapshot, snap)
    |> assign(:request_rows, request_rows)
    |> assign(:grant_rows, grant_rows)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      dev_routes={Application.get_env(:owlgate, :dev_routes, false)}
    >
      <div class="space-y-6 max-w-4xl">
        <div class="flex justify-between items-start gap-4 flex-wrap">
          <div>
            <h1 class="text-2xl font-semibold">Operator dashboard</h1>
            <p class="text-base-content/70 text-sm mt-1">
              Signed in as {@current_user.name} ({@current_user.role})
            </p>
          </div>
          <button type="button" phx-click="refresh" class="btn btn-outline btn-sm">
            Refresh
          </button>
        </div>

        <section>
          <h2 class="font-medium mb-3">Access requests</h2>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <div
              :for={{status, count} <- @request_rows}
              class="rounded-box border border-base-300 bg-base-200/40 p-4"
            >
              <div class="text-xs uppercase text-base-content/60">{status_label(status)}</div>
              <div class="text-2xl font-semibold tabular-nums">{count}</div>
            </div>
          </div>
        </section>

        <section>
          <h2 class="font-medium mb-3">Grants</h2>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div
              :for={{status, count} <- @grant_rows}
              class="rounded-box border border-base-300 bg-base-200/40 p-4"
            >
              <div class="text-xs uppercase text-base-content/60">{status_label(status)}</div>
              <div class="text-2xl font-semibold tabular-nums">{count}</div>
            </div>
          </div>
        </section>

        <div class="flex gap-3 flex-wrap">
          <.link navigate={~p"/access-requests"} class="btn btn-primary">
            Manage access requests
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_label(atom) when is_atom(atom), do: Atom.to_string(atom)
end
