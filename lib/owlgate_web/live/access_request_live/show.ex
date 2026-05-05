defmodule OwlGateWeb.AccessRequestLive.Show do
  @moduledoc "Inspect a single access request and optionally approve/deny when permitted."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Policy.AccessPolicy

  on_mount {OwlGateWeb.Live.Auth, :require_authenticated_user}

  @impl true
  def mount(%{"id" => id_param}, _session, socket) do
    case parse_id(id_param) do
      {:ok, id} ->
        case reload_request(socket, id) do
          {:ok, socket} ->
            {:ok, socket}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Access request not found.")
             |> push_navigate(to: ~p"/access-requests")}
        end

      :error ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid request id.")
         |> push_navigate(to: ~p"/access-requests")}
    end
  end

  defp parse_id(bin) when is_binary(bin) do
    case Integer.parse(bin) do
      {id, _} -> {:ok, id}
      :error -> :error
    end
  end

  defp reload_request(socket, id) do
    actor = socket.assigns.current_user

    case Access.fetch_access_request(id) do
      {:ok, request} ->
        can_review_pending =
          AccessPolicy.can_review?(actor) and request.status == :pending and
            AccessPolicy.can_self_approve?(actor, request.user)

        {:ok,
         socket
         |> assign(:request_id, id)
         |> assign(:request, request)
         |> assign(:can_review_pending, can_review_pending)
         |> assign(:action_error, nil)}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    actor = socket.assigns.current_user
    id = socket.assigns.request_id

    case Access.approve_request(actor, id) do
      {:ok, _request} ->
        {:ok, socket} = reload_request(socket, id)
        {:noreply, put_flash(socket, :info, "Request approved — provisioning queued.")}

      {:error, :forbidden} ->
        {:noreply, assign(socket, :action_error, "You cannot review this request.")}

      {:error, :invalid_status} ->
        {:noreply,
         assign(socket, :action_error, "This request cannot be approved in its current state.")}

      {:error, :self_approval_not_allowed} ->
        {:noreply, assign(socket, :action_error, "You cannot approve your own request.")}

      {:error, :high_risk_requires_owner_or_admin} ->
        {:noreply,
         assign(
           socket,
           :action_error,
           "High-risk applications require the app owner or an admin."
         )}

      {:error, reason} ->
        {:noreply, assign(socket, :action_error, "Unable to approve: #{inspect(reason)}")}
    end
  end

  def handle_event("deny", %{"reason" => reason}, socket) do
    actor = socket.assigns.current_user
    id = socket.assigns.request_id
    reason = String.trim(reason)

    case Access.deny_request(actor, id, reason) do
      {:ok, _} ->
        {:ok, socket} = reload_request(socket, id)
        {:noreply, put_flash(socket, :info, "Request denied.")}

      {:error, :forbidden} ->
        {:noreply, assign(socket, :action_error, "You cannot review this request.")}

      {:error, :invalid_status} ->
        {:noreply,
         assign(socket, :action_error, "This request cannot be denied in its current state.")}

      {:error, :denial_reason_required} ->
        {:noreply, assign(socket, :action_error, "A denial reason is required.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         assign(socket, :action_error, "Provide a clear denial reason (min 3 characters).")}
    end
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
        <div class="flex gap-4 flex-wrap items-center justify-between">
          <div>
            <p class="text-sm text-base-content/70 mb-1">Access request {@request.id}</p>
            <h1 class="text-2xl font-semibold">{@request.application.slug}</h1>
            <p class="mt-2 text-base-content/80">{@request.reason}</p>
          </div>
          <span class="badge badge-lg badge-outline">{@request.status}</span>
        </div>

        <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
          <div>
            <dt class="text-base-content/60">Requester</dt>
            <dd class="font-medium">{@request.user.email}</dd>
          </div>
          <div>
            <dt class="text-base-content/60">Application</dt>
            <dd class="font-medium">{@request.application.name}</dd>
          </div>
          <div>
            <dt class="text-base-content/60">Reviewed by</dt>
            <dd class="font-medium">
              <%= if @request.reviewed_by do %>
                {@request.reviewed_by.email}
              <% else %>
                —
              <% end %>
            </dd>
          </div>
        </dl>

        <%= if @request.status == :denied and @request.denial_reason do %>
          <div class="rounded-box border border-warning/40 bg-warning/10 p-3 text-sm">
            <strong>Denial reason:</strong>
            <span class="ml-2">{@request.denial_reason}</span>
          </div>
        <% end %>

        <%= if @action_error do %>
          <div class="text-sm text-error">{@action_error}</div>
        <% end %>

        <%= if @can_review_pending do %>
          <section class="rounded-box border border-base-300 p-4 bg-base-200/30 space-y-4">
            <h2 class="font-medium">Review</h2>
            <div class="flex gap-3 flex-wrap">
              <button type="button" phx-click="approve" class="btn btn-success btn-sm">
                Approve &amp; queue provisioning
              </button>
            </div>

            <div>
              <form id="deny-request" phx-submit="deny" class="grid gap-2 max-w-lg">
                <label class="form-control">
                  <span class="label-text text-sm">Denial reason</span>
                  <textarea
                    name="reason"
                    required
                    minlength="3"
                    class="textarea textarea-bordered textarea-sm"
                  />
                </label>
                <button type="submit" class="btn btn-error btn-sm w-fit">
                  Deny request
                </button>
              </form>
            </div>
          </section>
        <% end %>

        <div class="flex gap-3">
          <.link navigate={~p"/access-requests"} class="btn btn-ghost btn-sm">
            Back to list
          </.link>
          <.link navigate={~p"/dashboard"} class="btn btn-ghost btn-sm">
            Dashboard
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
