defmodule OwlGateWeb.Admin.UserLive.Index do
  @moduledoc "Admin listing for users."
  use OwlGateWeb, :live_view

  alias OwlGate.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, refresh(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => raw}, socket) do
    case Integer.parse(to_string(raw)) do
      {id, _} ->
        case Accounts.get_user(id) do
          nil ->
            {:noreply, put_flash(socket, :error, gettext("User not found."))}

          user ->
            case Accounts.delete_user(user) do
              {:ok, _} ->
                {:noreply,
                 socket
                 |> put_flash(:info, gettext("User deleted."))
                 |> refresh()}

              {:error, reason} ->
                {:noreply,
                 put_flash(
                   socket,
                   :error,
                   gettext("Cannot delete user (%{reason}).", reason: inspect(reason))
                 )}
            end
        end

      :error ->
        {:noreply, put_flash(socket, :error, gettext("Invalid id."))}
    end
  end

  defp refresh(socket) do
    assign(socket, :users, Accounts.list_users(preload: [:manager]))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-8"
    >
      <.operator_page_header
        title={gettext("Users")}
        subtitle={gettext("Create accounts and assign roles (admins only).")}
      >
        <:actions>
          <.link navigate={~p"/admin/users/new"} class="btn btn-primary btn-sm">
            {gettext("New user")}
          </.link>
        </:actions>
      </.operator_page_header>

      <div class="overflow-x-auto rounded-box border border-base-300">
        <table class="table table-sm table-zebra">
          <thead>
            <tr>
              <th>{gettext("Email")}</th>
              <th>{gettext("Name")}</th>
              <th>{gettext("Role")}</th>
              <th>{gettext("Manager")}</th>
              <th>{gettext("MFA")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@users == []}>
              <td colspan="6" class="text-center text-base-content/70">{gettext("No users.")}</td>
            </tr>
            <%= for u <- @users do %>
              <tr>
                <td class="font-mono text-xs">{u.email}</td>
                <td>{u.name}</td>
                <td><span class="badge badge-ghost">{u.role}</span></td>
                <td class="text-xs">{(u.manager && u.manager.email) || gettext("—")}</td>
                <td>{if u.mfa_required, do: gettext("yes"), else: gettext("no")}</td>
                <td class="flex flex-wrap gap-1">
                  <.link navigate={~p"/admin/users/#{u.id}/edit"} class="btn btn-ghost btn-xs">
                    {gettext("Edit")}
                  </.link>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={u.id}
                    phx-confirm={
                      gettext(
                        "Delete this user? This fails if they still own apps or have related records."
                      )
                    }
                    class="btn btn-error btn-xs btn-outline"
                  >
                    {gettext("Delete")}
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </.operator_shell>
    """
  end
end
