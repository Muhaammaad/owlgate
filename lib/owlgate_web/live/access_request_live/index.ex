defmodule OwlGateWeb.AccessRequestLive.Index do
  @moduledoc "List and create access requests."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Constants
  alias OwlGate.Accounts
  alias OwlGate.Policy.{AccessPolicy, AdminPolicy}
  alias OwlGateWeb.FormHelpers
  alias OwlGateWeb.Live.StatusFilter

  @filterable Enum.uniq(Constants.request_statuses() ++ Constants.grant_statuses())

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:filter_status, nil)
      |> assign(:search_query, "")
      |> assign(:form_error, nil)
      |> assign(:subject_user_picker?, AdminPolicy.admin?(user))
      |> assign(:subject_users, subject_users_for_picker(user))
      |> load_applications()
      |> load_requests()

    {:ok, socket}
  end

  defp subject_users_for_picker(%{role: :admin}), do: Accounts.list_users()
  defp subject_users_for_picker(_), do: []

  @impl true
  def handle_event("filter", params, socket) do
    status_raw = Map.get(params, "status")

    socket =
      StatusFilter.put_filter(socket, status_raw, @filterable,
        filter_key: :filter_status,
        error_key: :form_error
      )

    {:noreply, load_requests(socket)}
  end

  def handle_event("search_requests", %{"q" => q}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, q)
     |> load_requests()}
  end

  def handle_event("create", params, socket) do
    %{"reason" => reason, "application_id" => app_id} = params

    attrs =
      %{"application_id" => app_id, "reason" => String.trim(reason)}
      |> maybe_put_subject_user_param(socket.assigns.current_user, params)

    result = Access.create_request(socket.assigns.current_user, attrs)

    {:noreply, apply_create_result(socket, result, params)}
  end

  defp maybe_put_subject_user_param(attrs, %{role: :admin}, params) do
    case Map.get(params, "subject_user_id") do
      nil -> attrs
      "" -> attrs
      id -> Map.put(attrs, "subject_user_id", id)
    end
  end

  defp maybe_put_subject_user_param(attrs, _, _), do: attrs

  defp apply_create_result(socket, {:ok, request}, params) do
    actor = socket.assigns.current_user
    flow = Map.get(params, "admin_submit_flow", "pending_review")

    socket =
      socket
      |> assign(:form_error, nil)

    socket =
      if AdminPolicy.admin?(actor) && flow == "approve_immediately" do
        case Access.approve_request(actor, request.id) do
          {:ok, _} ->
            put_flash(
              socket,
              :info,
              gettext("Request created and approved; provisioning queued.")
            )

          {:error, reason} ->
            socket
            |> put_flash(:info, gettext("Access request submitted as pending."))
            |> put_flash(:error, quick_approve_error(reason))
        end
      else
        put_flash(socket, :info, gettext("Access request submitted."))
      end

    load_requests(socket)
  end

  defp apply_create_result(socket, {:error, %Ecto.Changeset{} = cs}, _params) do
    assign(socket, :form_error, FormHelpers.format_changeset_errors(cs))
  end

  defp apply_create_result(socket, {:error, reason}, _params) do
    assign(socket, :form_error, create_message(reason))
  end

  defp quick_approve_error(:forbidden),
    do: gettext("Auto-approve was not allowed for this request.")

  defp quick_approve_error(:invalid_status),
    do: gettext("Could not approve - request was not in a pending state.")

  defp quick_approve_error(:self_approval_not_allowed),
    do:
      gettext(
        "Could not approve - you cannot approve your own request when you are the requester."
      )

  defp quick_approve_error(:high_risk_requires_owner_or_admin),
    do: gettext("Could not approve - high-risk apps require the application owner or an admin.")

  defp quick_approve_error(other),
    do: gettext("Could not auto-approve: %{reason}", reason: inspect(other))

  defp create_message(:forbidden), do: gettext("You cannot request access for this application.")
  defp create_message(:inactive_application), do: gettext("That application is inactive.")

  defp create_message(:duplicate_request),
    do: gettext("An open access request already exists for this user and application.")

  defp create_message(:already_has_active_grant),
    do: gettext("This user already has active access for this application.")

  defp create_message(:subject_user_required), do: gettext("Choose which user the access is for.")
  defp create_message(:subject_user_not_found), do: gettext("That user no longer exists.")

  defp create_message(other),
    do: gettext("Unable to create request: %{reason}", reason: inspect(other))

  defp load_requests(socket) do
    user = socket.assigns.current_user

    opts =
      []

    opts =
      if AccessPolicy.employee_data_scope?(user),
        do: Keyword.put(opts, :user_id, user.id),
        else: opts

    opts =
      case socket.assigns[:search_query] do
        q when is_binary(q) and q != "" -> Keyword.put(opts, :search, q)
        _ -> opts
      end

    requests =
      Access.list_access_requests(opts)
      |> maybe_filter_by_display_status(socket.assigns.filter_status)

    assign(socket, :requests, requests)
  end

  defp maybe_filter_by_display_status(requests, nil), do: requests

  defp maybe_filter_by_display_status(requests, status) when is_atom(status) do
    Enum.filter(requests, fn request -> display_status(request) == status end)
  end

  defp display_status(%{grant: %{status: grant_status}}) when not is_nil(grant_status),
    do: grant_status

  defp display_status(%{status: request_status}), do: request_status

  defp load_applications(socket) do
    assign(socket, :applications, Access.list_applications())
  end

  defp can_submit?(%{applications: apps, current_user: user})
       when is_list(apps) and not is_nil(user) do
    apps != [] and Enum.any?(apps, &AccessPolicy.can_request?(user, &1))
  end

  defp can_submit?(_assigns), do: false

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :submit_enabled?, can_submit?(assigns))

    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-8"
    >
      <.operator_page_header
        title={gettext("Access requests")}
        subtitle={access_requests_subtitle(@current_user)}
      />

      <.new_access_request_form
        applications={@applications}
        form_error={@form_error}
        submit_enabled?={@submit_enabled?}
        subject_user_picker?={@subject_user_picker?}
        subject_users={@subject_users}
        admin_submit_flow?={@subject_user_picker?}
      />

      <section>
        <div class="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-end sm:justify-between mb-3">
          <h2 class="font-medium shrink-0">{access_requests_table_heading(@current_user)}</h2>
          <form phx-change="search_requests" class="w-full sm:max-w-xs">
            <label class="input input-bordered input-sm flex items-center gap-2 w-full">
              <span class="text-xs text-base-content/50 whitespace-nowrap">{gettext("Search")}</span>
              <input
                type="text"
                name="q"
                value={@search_query}
                placeholder={gettext("Requester email...")}
                autocomplete="off"
                phx-debounce="300"
                class="grow min-w-0 bg-transparent outline-none"
              />
            </label>
          </form>
          <.status_select_filter
            form_id="filter-form"
            statuses={filterable_statuses()}
            filter_status={@filter_status}
          />
        </div>

        <.access_requests_table requests={@requests} />
      </section>
    </.operator_shell>
    """
  end

  defp access_requests_subtitle(%{role: :admin} = user) do
    gettext(
      "Submit on behalf of someone (use Access for user below), or open any row to review. Signed in as %{name}.",
      name: user.name
    )
  end

  defp access_requests_subtitle(user) do
    if AccessPolicy.employee_data_scope?(user) do
      gettext("Submit access you need, or open one of your requests below.")
    else
      gettext("Create a request as %{name} or open a row to review approvals.", name: user.name)
    end
  end

  defp access_requests_table_heading(user) do
    if AccessPolicy.employee_data_scope?(user),
      do: gettext("My requests"),
      else: gettext("All requests")
  end

  defp filterable_statuses, do: @filterable
end
