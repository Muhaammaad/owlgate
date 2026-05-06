defmodule OwlGateWeb.Admin.ApplicationLive.Index do
  @moduledoc "Admin listing for integrated applications."
  use OwlGateWeb, :live_view

  alias OwlGate.Access

  @impl true
  def mount(_params, _session, socket) do
    {:ok, refresh(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => raw}, socket) do
    case Integer.parse(to_string(raw)) do
      {id, _} ->
        case Access.fetch_application(id) do
          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, gettext("Application not found."))}

          {:ok, app} ->
            case Access.delete_application(app) do
              {:ok, _} ->
                {:noreply,
                 socket
                 |> put_flash(:info, gettext("Application deleted."))
                 |> refresh()}

              {:error, reason} ->
                {:noreply,
                 put_flash(
                   socket,
                   :error,
                   gettext(
                     "Cannot delete (%{reason}). Remove requests/grants first.",
                     reason: inspect(reason)
                   )
                 )}
            end
        end

      :error ->
        {:noreply, put_flash(socket, :error, gettext("Invalid id."))}
    end
  end

  defp refresh(socket) do
    assign(socket, :applications, Access.list_applications())
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
        title={gettext("Apps")}
        subtitle={gettext("Define apps employees can request access to.")}
      >
        <:actions>
          <.link navigate={~p"/admin/applications/new"} class="btn btn-primary btn-sm">
            {gettext("New application")}
          </.link>
        </:actions>
      </.operator_page_header>

      <div class="overflow-x-auto rounded-box border border-base-300">
        <table class="table table-sm table-zebra">
          <thead>
            <tr>
              <th>{gettext("Name")}</th>
              <th>{gettext("Slug")}</th>
              <th>{gettext("Risk")}</th>
              <th>{gettext("Owner")}</th>
              <th>{gettext("Active")}</th>
              <th>{gettext("MFA")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@applications == []}>
              <td colspan="7" class="text-center text-base-content/70">
                {gettext("No applications.")}
              </td>
            </tr>
            <%= for a <- @applications do %>
              <tr>
                <td>{a.name}</td>
                <td class="font-mono text-xs">{a.slug}</td>
                <td><span class="badge badge-ghost">{a.risk_level}</span></td>
                <td class="text-xs">{a.owner.email}</td>
                <td>{if a.active, do: gettext("yes"), else: gettext("no")}</td>
                <td>{if a.requires_mfa, do: gettext("yes"), else: gettext("no")}</td>
                <td class="flex flex-wrap gap-1">
                  <.link navigate={~p"/admin/applications/#{a.id}/edit"} class="btn btn-ghost btn-xs">
                    {gettext("Edit")}
                  </.link>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={a.id}
                    phx-confirm={
                      gettext(
                        "Delete this application? Fails if access requests or grants still reference it."
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
