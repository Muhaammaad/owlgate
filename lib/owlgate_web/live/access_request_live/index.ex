defmodule OwlGateWeb.AccessRequestLive.Index do
  @moduledoc "List and create access requests."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Constants
  alias OwlGate.Policy.AccessPolicy

  on_mount {OwlGateWeb.Live.Auth, :require_authenticated_user}

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
      case status_raw do
        "" ->
          socket |> assign(:filter_status, nil) |> assign(:form_error, nil)

        raw when is_binary(raw) ->
          case Enum.find(@filterable, &(Atom.to_string(&1) == raw)) do
            nil -> assign(socket, :form_error, "Invalid status filter.")
            atom -> socket |> assign(:filter_status, atom) |> assign(:form_error, nil)
          end

        _ ->
          socket
      end

    {:noreply, load_requests(socket)}
  end

  def handle_event("create", %{"reason" => reason, "application_id" => app_id}, socket) do
    attrs = %{"application_id" => app_id, "reason" => String.trim(reason)}

    case Access.create_request(socket.assigns.current_user, attrs) do
      {:ok, _request} ->
        socket =
          socket
          |> put_flash(:info, "Access request submitted.")
          |> assign(:form_error, nil)
          |> load_requests()

        {:noreply, socket}

      {:error, :forbidden} ->
        {:noreply, assign(socket, :form_error, "You cannot request access for this application.")}

      {:error, :inactive_application} ->
        {:noreply, assign(socket, :form_error, "That application is inactive.")}

      {:error, :duplicate_request} ->
        {:noreply, assign(socket, :form_error, "You already have an open request for this app.")}

      {:error, :already_has_active_grant} ->
        {:noreply, assign(socket, :form_error, "You already have active access.")}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, :form_error, format_changeset(cs))}
    end
  end

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

  defp format_changeset(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errs} ->
      "#{field}: #{Enum.join(errs, ", ")}"
    end)
  rescue
    ArgumentError ->
      inspect(cs.errors)
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
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      dev_routes={Application.get_env(:owlgate, :dev_routes, false)}
    >
      <div class="space-y-8 max-w-4xl">
        <div class="flex justify-between gap-4 flex-wrap items-start">
          <div>
            <h1 class="text-2xl font-semibold">Access requests</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Create a request as {@current_user.name} or open a row to review approvals.
            </p>
          </div>
          <.link navigate={~p"/dashboard"} class="btn btn-ghost btn-sm">
            Dashboard
          </.link>
        </div>

        <section class="rounded-box border border-base-300 p-4 bg-base-200/30">
          <h2 class="font-medium mb-3">New request</h2>
          <%= if @applications == [] do %>
            <p class="text-sm text-base-content/70">
              No applications exist yet — seed or create apps before submitting requests.
            </p>
          <% else %>
            <form id="access-request-create" phx-submit="create" class="grid gap-3 max-w-xl">
              <label class="form-control">
                <span class="label-text text-sm">Application</span>
                <select name="application_id" class="select select-bordered w-full">
                  <%= for app <- @applications do %>
                    <option value={app.id}>{app.name} ({app.slug})</option>
                  <% end %>
                </select>
              </label>
              <label class="form-control">
                <span class="label-text text-sm">Reason (min 5 characters)</span>
                <textarea
                  name="reason"
                  class="textarea textarea-bordered w-full min-h-24"
                  placeholder="Explain why access is needed"
                  required
                />
              </label>
              <%= if @form_error do %>
                <p class="text-sm text-error">{@form_error}</p>
              <% end %>
              <button
                type="submit"
                disabled={not @submit_enabled?}
                class="btn btn-primary btn-sm disabled:opacity-50"
              >
                Submit request
              </button>
            </form>
          <% end %>
        </section>

        <section>
          <div class="flex flex-wrap gap-3 items-center justify-between mb-3">
            <h2 class="font-medium">All requests</h2>
            <form id="filter-form">
              <label class="form-control inline-flex flex-row gap-2 items-center">
                <span class="text-sm whitespace-nowrap">Status</span>
                <select name="status" phx-change="filter" class="select select-bordered select-sm">
                  <option value="">Any</option>
                  <option value="pending" selected={@filter_status == :pending}>pending</option>
                  <option value="approved" selected={@filter_status == :approved}>approved</option>
                  <option value="denied" selected={@filter_status == :denied}>denied</option>
                  <option value="provisioning" selected={@filter_status == :provisioning}>
                    provisioning
                  </option>
                  <option value="provisioned" selected={@filter_status == :provisioned}>
                    provisioned
                  </option>
                  <option value="failed" selected={@filter_status == :failed}>failed</option>
                </select>
              </label>
            </form>
          </div>

          <div class="overflow-x-auto rounded-box border border-base-300">
            <table class="table table-sm table-zebra">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Requester</th>
                  <th>Application</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :if={@requests == []}>
                  <td colspan="5" class="text-center text-base-content/70">No matching requests.</td>
                </tr>
                <%= for r <- @requests do %>
                  <tr>
                    <td class="font-mono">{r.id}</td>
                    <td>{r.user.email}</td>
                    <td>{r.application.slug}</td>
                    <td>
                      <span class="badge badge-ghost">{r.status}</span>
                    </td>
                    <td>
                      <.link navigate={~p"/access-requests/#{r.id}"} class="link link-primary text-sm">
                        Open
                      </.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
