defmodule OwlGateWeb.Admin.ApplicationLive.Form do
  @moduledoc "Admin create/edit application."
  use OwlGateWeb, :live_view

  alias OwlGate.Access
  alias OwlGate.Access.Application, as: GateApp
  alias OwlGate.Accounts

  @risk_levels [:low, :medium, :high]

  @impl true
  def mount(params, _session, socket) do
    owners = Accounts.list_owner_candidates()

    socket =
      socket
      |> assign(:owners, owners)
      |> assign(:risk_options, @risk_levels)

    {:ok, load_form(socket, params)}
  end

  defp load_form(socket, params) do
    case Map.get(params, "id") do
      nil ->
        empty =
          struct(GateApp, %{risk_level: :low, active: true, requires_mfa: false})

        socket
        |> assign(:page_title, gettext("New application"))
        |> assign(:application, nil)
        |> assign(:changeset, Access.change_application(empty))

      raw_id ->
        case Integer.parse(to_string(raw_id)) do
          {id, _} ->
            case Access.fetch_application(id) do
              {:error, :not_found} ->
                socket
                |> put_flash(:error, gettext("Application not found."))
                |> push_navigate(to: ~p"/admin/applications")

              {:ok, %GateApp{} = app} ->
                socket
                |> assign(:page_title, gettext("Edit application"))
                |> assign(:application, app)
                |> assign(:changeset, Access.change_application(app))
            end

          :error ->
            socket
            |> put_flash(:error, gettext("Invalid application id."))
            |> push_navigate(to: ~p"/admin/applications")
        end
    end
  end

  @impl true
  def handle_event("save", %{"application" => params}, socket) do
    params = normalize_app_params(params)

    case socket.assigns.application do
      nil ->
        case Access.create_application(params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Application created."))
             |> push_navigate(to: ~p"/admin/applications")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :changeset, cs)}
        end

      app ->
        case Access.update_application(app, params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Application updated."))
             |> push_navigate(to: ~p"/admin/applications")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :changeset, cs)}
        end
    end
  end

  defp normalize_app_params(params) do
    params
    |> Map.update("owner_id", nil, &blank_to_nil_or_string/1)
  end

  defp blank_to_nil_or_string(""), do: nil
  defp blank_to_nil_or_string(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-8 max-w-xl"
    >
      <.operator_page_header
        title={@page_title}
        subtitle={gettext("Slug is normalized to lowercase kebab-case.")}
      >
        <:actions>
          <.link navigate={~p"/admin/applications"} class="btn btn-ghost btn-sm">
            {gettext("Back")}
          </.link>
        </:actions>
      </.operator_page_header>

      <.form
        :let={f}
        for={to_form(@changeset, as: :application)}
        phx-submit="save"
        class="rounded-box border border-base-300 bg-base-200/30 p-6 space-y-4"
      >
        <.input field={f[:name]} type="text" label={gettext("Name")} required />
        <.input field={f[:slug]} type="text" label={gettext("Slug")} required />

        <label class="form-control w-full">
          <span class="label-text text-sm">{gettext("Risk level")}</span>
          <select name="application[risk_level]" class="select select-bordered w-full">
            <%= for r <- @risk_options do %>
              <option value={r} selected={Ecto.Changeset.get_field(@changeset, :risk_level) == r}>
                {r}
              </option>
            <% end %>
          </select>
        </label>

        <label class="form-control w-full">
          <span class="label-text text-sm">{gettext("Owner")}</span>
          <select name="application[owner_id]" class="select select-bordered w-full" required>
            <option value="">{gettext("— pick owner —")}</option>
            <%= for o <- @owners do %>
              <option value={o.id} selected={Ecto.Changeset.get_field(@changeset, :owner_id) == o.id}>
                {o.email} ({o.role})
              </option>
            <% end %>
          </select>
        </label>

        <label class="label cursor-pointer justify-start gap-3 my-4">
          <input type="hidden" name="application[active]" value="false" />
          <input
            type="checkbox"
            name="application[active]"
            value="true"
            checked={Ecto.Changeset.get_field(@changeset, :active) != false}
            class="checkbox checkbox-sm"
          />
          <span class="label-text">{gettext("Active")}</span>
        </label>

        <label class="label cursor-pointer justify-start gap-3">
          <input type="hidden" name="application[requires_mfa]" value="false" />
          <input
            type="checkbox"
            name="application[requires_mfa]"
            value="true"
            checked={Ecto.Changeset.get_field(@changeset, :requires_mfa) == true}
            class="checkbox checkbox-sm"
          />
          <span class="label-text">{gettext("Requires MFA")}</span>
        </label>

        <div class="flex justify-end">
          <button type="submit" class="btn btn-primary">{gettext("Save")}</button>
        </div>
      </.form>
    </.operator_shell>
    """
  end
end
