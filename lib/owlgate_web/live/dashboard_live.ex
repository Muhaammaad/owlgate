defmodule OwlGateWeb.DashboardLive do
  @moduledoc "Operator dashboard with access request and grant counts."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Constants

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

    socket
    |> assign(:request_rows, row_pairs(snap.requests, Constants.request_statuses()))
    |> assign(:grant_rows, row_pairs(snap.grants, Constants.grant_statuses()))
  end

  defp row_pairs(counts_map, statuses) do
    Enum.map(statuses, fn status -> {status, Map.fetch!(counts_map, status)} end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      dev_routes={Application.get_env(:owlgate, :dev_routes, false)}
      wrapper_class="space-y-6"
    >
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

      <.dashboard_snapshot_cards request_rows={@request_rows} grant_rows={@grant_rows} />

      <div class="flex gap-3 flex-wrap">
        <.link navigate={~p"/access-requests"} class="btn btn-primary">
          Manage access requests
        </.link>
      </div>
    </.operator_shell>
    """
  end
end
