defmodule OwlGateWeb.GrantLive.Index do
  @moduledoc "Lists access grants with revoke controls for reviewers."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Constants
  alias OwlGate.Policy.AccessPolicy
  alias OwlGateWeb.Live.StatusFilter

  @filterable Constants.grant_statuses()

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:filter_status, nil)
      |> assign(:action_error, nil)
      |> load_grants()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    status_raw = Map.get(params, "status")

    socket =
      StatusFilter.put_filter(socket, status_raw, @filterable,
        filter_key: :filter_status,
        error_key: :action_error
      )

    {:noreply, load_grants(socket)}
  end

  def handle_event("revoke", %{"id" => raw_id}, socket) do
    actor = socket.assigns.current_user

    with {id, _} <- Integer.parse(to_string(raw_id)),
         {:ok, _grant} <- Access.request_revoke(actor, id) do
      socket =
        socket
        |> put_flash(:info, gettext("Revoke job queued."))
        |> assign(:action_error, nil)
        |> load_grants()

      {:noreply, socket}
    else
      :error ->
        {:noreply, assign(socket, :action_error, gettext("Invalid grant id."))}

      {:error, :not_found} ->
        {:noreply, assign(socket, :action_error, gettext("Grant not found."))}

      {:error, :forbidden} ->
        {:noreply, assign(socket, :action_error, gettext("You cannot revoke grants."))}

      {:error, :invalid_status} ->
        {:noreply, assign(socket, :action_error, gettext("Grant is not active."))}

      {:error, _} = err ->
        {:noreply, assign(socket, :action_error, inspect(err))}
    end
  end

  defp load_grants(socket) do
    user = socket.assigns.current_user

    opts =
      case socket.assigns.filter_status do
        nil -> []
        status when status in @filterable -> [status: status]
        _ -> []
      end

    opts =
      if AccessPolicy.employee_data_scope?(user),
        do: Keyword.put(opts, :user_id, user.id),
        else: opts

    assign(socket, :grants, Access.list_grants(opts))
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :can_revoke?,
        AccessPolicy.can_review?(assigns.current_user)
      )

    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-8"
    >
      <.operator_page_header
        title={gettext("Access grants")}
        subtitle={grant_page_subtitle(@current_user)}
      />

      <p :if={@action_error} class="text-sm text-error">{@action_error}</p>

      <div class="flex flex-wrap gap-3 items-center justify-between">
        <h2 class="font-medium sr-only">{gettext("Filter")}</h2>
        <.status_select_filter
          form_id="grant-filter-form"
          statuses={Constants.grant_statuses()}
          filter_status={@filter_status}
        />
      </div>

      <.grants_table grants={@grants} can_revoke?={@can_revoke?} />
    </.operator_shell>
    """
  end

  defp grant_page_subtitle(user) do
    if AccessPolicy.employee_data_scope?(user) do
      gettext("Your provisioned access. Contact a manager if something looks wrong.")
    else
      gettext(
        "Active provisioning outcomes across all users. Managers and admins can queue revokes on active grants."
      )
    end
  end
end
