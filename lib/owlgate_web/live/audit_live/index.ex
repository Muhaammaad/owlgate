defmodule OwlGateWeb.AuditLive.Index do
  @moduledoc "Append-only audit event stream for operators."
  use OwlGateWeb, :live_view

  alias OwlGate.Audit
  alias OwlGate.Access.Constants
  alias OwlGate.Policy.AccessPolicy

  @impl true
  def mount(_params, _session, socket) do
    entity_options = [
      {"", "Any entity"},
      {Constants.entity_access_request(), "Access request"},
      {Constants.entity_access_grant(), "Access grant"}
    ]

    socket =
      socket
      |> assign(:filter_action, "")
      |> assign(:filter_entity, "")
      |> assign(:entity_options, entity_options)
      |> load_events()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    action = Map.get(params, "action", "") |> String.trim()
    entity = Map.get(params, "entity_type", "")

    socket =
      socket
      |> assign(:filter_action, action)
      |> assign(:filter_entity, entity)

    {:noreply, load_events(socket)}
  end

  defp load_events(socket) do
    action = trim_to_nil(socket.assigns.filter_action)
    entity = trim_to_nil(socket.assigns.filter_entity)

    user = socket.assigns.current_user

    opts =
      [limit: 250]
      |> Keyword.merge(if action, do: [action: action], else: [])
      |> Keyword.merge(if entity, do: [entity_type: entity], else: [])

    opts =
      if AccessPolicy.employee_data_scope?(user),
        do: Keyword.put(opts, :viewer_user_id, user.id),
        else: opts

    assign(socket, :events, Audit.list_events(opts))
  end

  defp trim_to_nil(""), do: nil
  defp trim_to_nil(s) when is_binary(s), do: s

  @impl true
  def render(assigns) do
    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-8"
    >
      <.operator_page_header
        title="Audit events"
        subtitle={audit_page_subtitle(@current_user)}
      />

      <.audit_filter_form
        filter_action={@filter_action}
        filter_entity={@filter_entity}
        entity_options={@entity_options}
      />

      <.audit_events_table events={@events} />
    </.operator_shell>
    """
  end

  defp audit_page_subtitle(user) do
    if AccessPolicy.employee_data_scope?(user) do
      "Your activity and access events (latest 250 rows shown)."
    else
      "Immutable log of privileged transitions for all users (latest 250 rows shown)."
    end
  end
end
