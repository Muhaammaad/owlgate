defmodule OwlGateWeb.AccessRequestLive.Index do
  @moduledoc "List and create access requests."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Constants
  alias OwlGate.Policy.AccessPolicy
  alias OwlGateWeb.FormHelpers
  alias OwlGateWeb.Live.StatusFilter

  @filterable Constants.request_statuses()

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:filter_status, nil)
      |> assign(:form_error, nil)
      |> load_applications()
      |> load_requests()

    {:ok, socket}
  end

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

  def handle_event("create", %{"reason" => reason, "application_id" => app_id}, socket) do
    attrs = %{"application_id" => app_id, "reason" => String.trim(reason)}

    {:noreply,
     socket
     |> apply_create(Access.create_request(socket.assigns.current_user, attrs))}
  end

  defp apply_create(socket, {:ok, _request}) do
    socket
    |> put_flash(:info, "Access request submitted.")
    |> assign(:form_error, nil)
    |> load_requests()
  end

  defp apply_create(socket, {:error, %Ecto.Changeset{} = cs}) do
    assign(socket, :form_error, FormHelpers.format_changeset_errors(cs))
  end

  defp apply_create(socket, {:error, reason}) do
    assign(socket, :form_error, create_message(reason))
  end

  defp create_message(:forbidden), do: "You cannot request access for this application."
  defp create_message(:inactive_application), do: "That application is inactive."
  defp create_message(:duplicate_request), do: "You already have an open request for this app."
  defp create_message(:already_has_active_grant), do: "You already have active access."
  defp create_message(other), do: "Unable to create request: #{inspect(other)}"

  defp load_requests(socket) do
    opts =
      case socket.assigns.filter_status do
        nil -> []
        status when status in @filterable -> [status: status]
        _ -> []
      end

    assign(socket, :requests, Access.list_access_requests(opts))
  end

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
      dev_routes={Application.get_env(:owlgate, :dev_routes, false)}
      wrapper_class="space-y-8"
    >
      <.operator_page_header
        title="Access requests"
        subtitle={"Create a request as #{@current_user.name} or open a row to review approvals."}
      >
        <:actions>
          <.operator_quick_links omit={[:requests, :grants, :audit]} />
        </:actions>
      </.operator_page_header>

      <.new_access_request_form
        applications={@applications}
        form_error={@form_error}
        submit_enabled?={@submit_enabled?}
      />

      <section>
        <div class="flex flex-wrap gap-3 items-center justify-between mb-3">
          <h2 class="font-medium">All requests</h2>
          <.status_select_filter
            form_id="filter-form"
            statuses={Constants.request_statuses()}
            filter_status={@filter_status}
          />
        </div>

        <.access_requests_table requests={@requests} />
      </section>
    </.operator_shell>
    """
  end
end
