defmodule OwlGateWeb.AccessRequestLive.Show do
  @moduledoc "Inspect a single access request and optionally approve/deny when permitted."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.AccessGrant
  alias OwlGate.Policy.{AccessPolicy, AdminPolicy}

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
        can_review_pending = review_allowed?(actor, request)

        grant =
          case Access.fetch_grant_by_access_request_id(request.id) do
            {:ok, g} -> g
            {:error, :not_found} -> nil
          end

        show_admin_revoke? =
          AdminPolicy.admin?(actor) && grant && grant.status == :active

        {:ok,
         socket
         |> assign(:request_id, id)
         |> assign(:request, request)
         |> assign(:grant, grant)
         |> assign(:show_admin_revoke_grant?, show_admin_revoke?)
         |> assign(:can_review_pending?, can_review_pending)
         |> assign(:action_error, nil)}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp review_allowed?(actor, request) do
    AccessPolicy.can_review?(actor) and request.status == :pending and
      AccessPolicy.can_self_approve?(actor, request.user)
  end

  @impl true
  def handle_event("approve", _params, socket) do
    actor = socket.assigns.current_user
    id = socket.assigns.request_id

    {:noreply,
     actor
     |> Access.approve_request(id)
     |> fold_approve(socket, id)}
  end

  def handle_event("deny", %{"reason" => reason}, socket) do
    actor = socket.assigns.current_user
    id = socket.assigns.request_id
    reason = String.trim(reason)

    {:noreply,
     actor
     |> Access.deny_request(id, reason)
     |> fold_deny(socket, id)}
  end

  def handle_event("revoke_grant", %{"id" => raw_id}, socket) do
    actor = socket.assigns.current_user

    if not AdminPolicy.admin?(actor) do
      {:noreply, assign(socket, :action_error, "Only admins can queue revoke from this page.")}
    else
      req_id = socket.assigns.request_id

      with {gid, _} <- Integer.parse(to_string(raw_id)),
           {:ok, %AccessGrant{access_request_id: arid} = g} <- Access.fetch_grant(gid),
           true <- arid == req_id,
           {:ok, _} <- Access.request_revoke(actor, g.id),
           {:ok, socket} <- reload_request(socket, req_id) do
        {:noreply,
         socket
         |> assign(:action_error, nil)
         |> put_flash(:info, "Revoke job queued.")}
      else
        :error ->
          {:noreply, assign(socket, :action_error, "Invalid grant id.")}

        false ->
          {:noreply, assign(socket, :action_error, "That grant is not linked to this request.")}

        {:error, :not_found} ->
          {:noreply, assign(socket, :action_error, "Grant not found.")}

        {:error, :forbidden} ->
          {:noreply, assign(socket, :action_error, "You cannot revoke this grant.")}

        {:error, :invalid_status} ->
          {:noreply, assign(socket, :action_error, "Grant is not active.")}

        {:error, _} = err ->
          {:noreply, assign(socket, :action_error, "Unable to revoke: #{inspect(err)}")}
      end
    end
  end

  defp fold_approve({:ok, _}, socket, id) do
    {:ok, socket} = reload_request(socket, id)
    put_flash(socket, :info, "Request approved — provisioning queued.")
  end

  defp fold_approve({:error, :forbidden}, socket, _id) do
    assign(socket, :action_error, "You cannot review this request.")
  end

  defp fold_approve({:error, :invalid_status}, socket, _id) do
    assign(socket, :action_error, "This request cannot be approved in its current state.")
  end

  defp fold_approve({:error, :self_approval_not_allowed}, socket, _id) do
    assign(socket, :action_error, "You cannot approve your own request.")
  end

  defp fold_approve({:error, :high_risk_requires_owner_or_admin}, socket, _id) do
    assign(socket, :action_error, "High-risk applications require the app owner or an admin.")
  end

  defp fold_approve({:error, reason}, socket, _id) do
    assign(socket, :action_error, "Unable to approve: #{inspect(reason)}")
  end

  defp fold_deny({:ok, _}, socket, id) do
    {:ok, socket} = reload_request(socket, id)
    put_flash(socket, :info, "Request denied.")
  end

  defp fold_deny({:error, :forbidden}, socket, _id) do
    assign(socket, :action_error, "You cannot review this request.")
  end

  defp fold_deny({:error, :invalid_status}, socket, _id) do
    assign(socket, :action_error, "This request cannot be denied in its current state.")
  end

  defp fold_deny({:error, :denial_reason_required}, socket, _id) do
    assign(socket, :action_error, "A denial reason is required.")
  end

  defp fold_deny({:error, %Ecto.Changeset{}}, socket, _id) do
    assign(socket, :action_error, "Provide a clear denial reason (min 3 characters).")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-6"
    >
      <.access_request_heading request={@request} />
      <.access_request_facts request={@request} />
      <.access_request_denial_notice request={@request} />

      <div :if={@action_error} class="text-sm text-error">
        {@action_error}
      </div>

      <.access_request_review_panel can_review_pending?={@can_review_pending?} />

      <.access_request_grant_admin_panel
        grant={@grant}
        show_admin_revoke?={@show_admin_revoke_grant?}
      />

      <div class="flex flex-wrap gap-3">
        <.link navigate={~p"/access-requests"} class="btn btn-ghost btn-sm">
          Back to list
        </.link>
      </div>
    </.operator_shell>
    """
  end
end
