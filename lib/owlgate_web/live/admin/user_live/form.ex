defmodule OwlGateWeb.Admin.UserLive.Form do
  @moduledoc "Admin create/edit user form."
  use OwlGateWeb, :live_view

  alias OwlGate.Accounts
  alias OwlGate.Accounts.User

  @impl true
  def mount(params, _session, socket) do
    managers = Accounts.list_managers()

    socket =
      socket
      |> assign(:managers, managers)
      |> assign(:role_options, User.roles())

    {:ok, load_form(socket, params)}
  end

  defp load_form(socket, params) do
    case Map.get(params, "id") do
      nil ->
        socket
        |> assign(:page_title, gettext("New user"))
        |> assign(:user, nil)
        |> assign(:changeset, Accounts.change_user_admin_create())

      raw_id ->
        case Integer.parse(to_string(raw_id)) do
          {id, _} ->
            case Accounts.get_user(id) do
              nil ->
                socket
                |> put_flash(:error, gettext("User not found."))
                |> push_navigate(to: ~p"/admin/users")

              %User{} = user ->
                socket
                |> assign(:page_title, gettext("Edit user"))
                |> assign(:user, user)
                |> assign(:changeset, Accounts.change_user_admin(user))
            end

          :error ->
            socket
            |> put_flash(:error, gettext("Invalid user id."))
            |> push_navigate(to: ~p"/admin/users")
        end
    end
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    params = normalize_params(params)

    case socket.assigns.user do
      nil ->
        case Accounts.create_user_with_password(params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("User created."))
             |> push_navigate(to: ~p"/admin/users")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :changeset, cs)}
        end

      user ->
        case Accounts.update_user_managed(user, params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("User updated."))
             |> push_navigate(to: ~p"/admin/users")}

          {:error, %Ecto.Changeset{} = cs} ->
            {:noreply, assign(socket, :changeset, cs)}
        end
    end
  end

  defp normalize_params(params) do
    Map.update(params, "manager_id", nil, fn
      "" -> nil
      v -> v
    end)
  end

  @impl true
  def render(assigns) do
    role = Ecto.Changeset.get_field(assigns.changeset, :role)
    mfaid = Ecto.Changeset.get_field(assigns.changeset, :manager_id)

    assigns = assign(assigns, :selected_role, role)
    assigns = assign(assigns, :selected_manager_id, mfaid)

    ~H"""
    <.operator_shell
      flash={@flash}
      current_user={@current_user}
      wrapper_class="space-y-8 max-w-xl"
    >
      <.operator_page_header
        title={@page_title}
        subtitle={gettext("Password required on create; optional on update (leave blank to keep).")}
      >
        <:actions>
          <.link navigate={~p"/admin/users"} class="btn btn-ghost btn-sm">{gettext("Back")}</.link>
        </:actions>
      </.operator_page_header>

      <.form
        :let={f}
        for={to_form(@changeset, as: :user)}
        phx-submit="save"
        class="rounded-box border border-base-300 bg-base-200/30 p-6 space-y-4"
      >
        <.input field={f[:email]} type="email" label={gettext("Email")} required />
        <.input field={f[:name]} type="text" label={gettext("Name")} required />

        <label class="form-control w-full">
          <span class="label-text text-sm">{gettext("Role")}</span>
          <select name="user[role]" class="select select-bordered w-full">
            <%= for r <- @role_options do %>
              <option value={r} selected={@selected_role == r}>{r}</option>
            <% end %>
          </select>
        </label>

        <label class="form-control w-full">
          <span class="label-text text-sm">{gettext("Manager (optional)")}</span>
          <select name="user[manager_id]" class="select select-bordered w-full">
            <option value="">—</option>
            <%= for m <- @managers do %>
              <option value={m.id} selected={@selected_manager_id == m.id}>
                {m.email}
              </option>
            <% end %>
          </select>
          <span class="label-text-alt text-xs text-base-content/60 leading-snug pt-1">
            {gettext(
              "Stored for future use (e.g. routing approvals or scoped visibility by org hierarchy). Access rules today follow role only; manager links do not change behavior yet."
            )}
          </span>
        </label>

        <div class="form-control w-full gap-2">
          <label class="label cursor-pointer justify-start gap-3 py-0">
            <input type="hidden" name="user[mfa_required]" value="false" />
            <input
              type="checkbox"
              name="user[mfa_required]"
              value="true"
              checked={Ecto.Changeset.get_field(@changeset, :mfa_required) == true}
              class="checkbox checkbox-sm"
            />
            <span class="label-text">{gettext("MFA required")}</span>
          </label>
          <p class="text-xs text-base-content/60 leading-snug pl-9">
            {gettext(
              "Reserved for future policy: require MFA at sign-in or for sensitive actions before enforcement is wired up. Toggling this does not affect login yet."
            )}
          </p>
        </div>

        <.auth_password_input
          :if={is_nil(@user)}
          id="admin-new-user-password"
          name="user[password]"
          label={gettext("Password")}
          required
          autocomplete="new-password"
        />

        <.input
          :if={@user}
          field={f[:password]}
          type="password"
          label={gettext("Password (optional)")}
          autocomplete="new-password"
        />
        <div class="flex justify-end my-4">
          <button type="submit" class="btn btn-primary">{gettext("Save")}</button>
        </div>
      </.form>
    </.operator_shell>
    """
  end
end
