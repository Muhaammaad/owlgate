defmodule OwlGateWeb.DashboardLive do
  @moduledoc "Operator dashboard with access request and grant counts."
  use OwlGateWeb, :live_view

  alias OwlGate.{Access, Audit}
  alias OwlGate.Access.Constants
  alias OwlGate.Policy.AccessPolicy

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_snapshot(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign_snapshot(socket)}
  end

  defp assign_snapshot(socket) do
    user = socket.assigns.current_user

    opts =
      if AccessPolicy.employee_data_scope?(user),
        do: [scope_user_id: user.id],
        else: []

    snap = Access.dashboard_snapshot(opts)

    recent =
      Audit.list_events(recent_audit_opts(user))

    socket
    |> assign(:request_rows, row_pairs(snap.requests, Constants.request_statuses()))
    |> assign(:grant_rows, row_pairs(snap.grants, Constants.grant_statuses()))
    |> assign(:recent_events, recent)
  end

  defp recent_audit_opts(%{} = user) do
    opts = [limit: 12]

    if AccessPolicy.employee_data_scope?(user) do
      Keyword.put(opts, :viewer_user_id, user.id)
    else
      opts
    end
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
      wrapper_class="space-y-6"
    >
      <div class="flex justify-between items-start gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-semibold">{gettext("Operator dashboard")}</h1>
          <p class="text-base-content/70 text-sm mt-1">
            {gettext("Signed in as %{name} (%{role})",
              name: @current_user.name,
              role: @current_user.role
            )}
          </p>
        </div>
        <button type="button" phx-click="refresh" class="btn btn-outline btn-sm">
          {gettext("Refresh")}
        </button>
      </div>

      <.dashboard_snapshot_cards request_rows={@request_rows} grant_rows={@grant_rows} />

      <section class="space-y-3">
        <div class="flex flex-wrap justify-between items-center gap-2">
          <h2 class="font-medium">{gettext("Recent activity")}</h2>
          <.link navigate={~p"/audit-events"} class="link link-primary text-sm">
            {gettext("Full audit log")}
          </.link>
        </div>
        <.audit_events_table events={@recent_events} />
      </section>

      <div class="flex gap-3 flex-wrap">
        <.link navigate={~p"/access-requests"} class="btn btn-primary">
          {gettext("Manage access requests")}
        </.link>
      </div>
    </.operator_shell>
    """
  end
end
