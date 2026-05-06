defmodule OwlGateWeb.OperatorComponents do
  @moduledoc "Shared layout chrome for operator LiveViews (headers, nav links, shells)."

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: OwlGateWeb.Endpoint,
    router: OwlGateWeb.Router,
    statics: OwlGateWeb.static_paths()

  alias OwlGateWeb.Layouts

  attr :flash, :map, required: true
  attr :current_user, :any, default: nil
  attr :wrapper_class, :string, default: "space-y-8 max-w-5xl"

  slot :inner_block, required: true

  def operator_shell(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class={@wrapper_class}>
        {render_slot(@inner_block)}
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  slot :actions, doc: "Right-side links or buttons (e.g. quick nav)"

  def operator_page_header(assigns) do
    ~H"""
    <div class="flex justify-between gap-4 flex-wrap items-start">
      <div>
        <h1 class="text-2xl font-semibold">{@title}</h1>
        <p :if={@subtitle} class="mt-1 text-sm text-base-content/70">
          {@subtitle}
        </p>
      </div>
      <div :if={@actions != []} class="flex gap-2 flex-wrap">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  attr :filter_action, :string, required: true
  attr :filter_entity, :string, required: true
  attr :entity_options, :list, required: true, doc: "{value, label} tuples"

  def audit_filter_form(assigns) do
    ~H"""
    <form
      id="audit-filter-form"
      phx-change="filter"
      class="rounded-box border border-base-300 p-4 flex flex-wrap gap-4 items-end"
    >
      <label class="form-control">
        <span class="label-text text-xs">Action (exact)</span>
        <input
          type="text"
          name="action"
          value={@filter_action}
          placeholder="e.g. access_request.approved"
          class="input input-bordered input-sm w-64 max-w-full"
        />
      </label>
      <label class="form-control">
        <span class="label-text text-xs">Entity type</span>
        <select name="entity_type" class="select select-bordered select-sm w-56">
          <%= for {val, label} <- @entity_options do %>
            <option value={val} selected={@filter_entity == val}>{label}</option>
          <% end %>
        </select>
      </label>
    </form>
    """
  end

  attr :events, :list, required: true

  def audit_events_table(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded-box border border-base-300">
      <table class="table table-xs sm:table-sm table-zebra">
        <thead>
          <tr>
            <th>When</th>
            <th>Actor</th>
            <th>Action</th>
            <th>Entity</th>
            <th>Meta</th>
          </tr>
        </thead>
        <tbody>
          <tr :if={@events == []}>
            <td colspan="5" class="text-center text-base-content/70">No matching events.</td>
          </tr>
          <%= for e <- @events do %>
            <tr>
              <td class="whitespace-nowrap text-xs">{format_occurred_at(e.occurred_at)}</td>
              <td class="text-xs">{actor_email_or_id(e.actor)}</td>
              <td class="font-mono text-xs">{e.action}</td>
              <td class="text-xs">
                {format_entity_ref(e.entity_type, e.entity_id)}
              </td>
              <td class="max-w-xs truncate text-xs opacity-90">
                <%= if e.metadata == %{} do %>
                  —
                <% else %>
                  {inspect(e.metadata)}
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :requests, :list, required: true

  def access_requests_table(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded-box border border-base-300">
      <table class="table table-sm table-zebra">
        <thead>
          <tr>
            <th>ID</th>
            <th>Requester</th>
            <th>Application</th>
            <th>Status</th>
            <th>Reviewer</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :if={@requests == []}>
            <td colspan="6" class="text-center text-base-content/70">No matching requests.</td>
          </tr>
          <%= for r <- @requests do %>
            <tr>
              <td class="font-mono">{r.id}</td>
              <td>{r.user.email}</td>
              <td>{r.application.slug}</td>
              <td>
                <span class="badge badge-ghost">{r.status}</span>
              </td>
              <td class="text-sm">
                <%= if r.reviewed_by do %>
                  <span class="font-medium">{r.reviewed_by.email}</span>
                  <span class="block text-xs text-base-content/60">{reviewer_action_hint(r.status)}</span>
                <% else %>
                  <span class="text-base-content/50">—</span>
                <% end %>
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
    """
  end

  attr :grants, :list, required: true
  attr :can_revoke?, :boolean, required: true

  def grants_table(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded-box border border-base-300">
      <table class="table table-sm table-zebra">
        <thead>
          <tr>
            <th>ID</th>
            <th>User</th>
            <th>Application</th>
            <th>Status</th>
            <th>External ref</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :if={@grants == []}>
            <td colspan="6" class="text-center text-base-content/70">No matching grants.</td>
          </tr>
          <%= for g <- @grants do %>
            <tr>
              <td class="font-mono">{g.id}</td>
              <td>{g.user.email}</td>
              <td>{g.application.slug}</td>
              <td><span class="badge badge-ghost">{g.status}</span></td>
              <td class="font-mono text-xs max-w-[14rem] truncate">{g.external_ref || "—"}</td>
              <td>
                <button
                  :if={@can_revoke? and g.status == :active}
                  type="button"
                  phx-click="revoke"
                  phx-value-id={g.id}
                  class="btn btn-warning btn-xs"
                >
                  Queue revoke
                </button>
                <span
                  :if={not @can_revoke? or g.status != :active}
                  class="text-xs text-base-content/50"
                >
                  <%= if g.status != :active do %>
                    —
                  <% else %>
                    review role required
                  <% end %>
                </span>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :form_id, :string, default: "status-filter-form"
  attr :filter_status, :any, default: nil, doc: "Selected status atom or nil"
  attr :statuses, :list, required: true, doc: "Atoms rendered as options"

  def status_select_filter(assigns) do
    ~H"""
    <form id={@form_id}>
      <label class="form-control inline-flex flex-row gap-2 items-center">
        <span class="text-sm whitespace-nowrap">Status</span>
        <select name="status" phx-change="filter" class="select select-bordered select-sm">
          <option value="">Any</option>
          <%= for s <- @statuses do %>
            <option value={Atom.to_string(s)} selected={@filter_status == s}>
              {Atom.to_string(s)}
            </option>
          <% end %>
        </select>
      </label>
    </form>
    """
  end

  attr :applications, :list, required: true
  attr :form_error, :any, default: nil
  attr :submit_enabled?, :boolean, required: true
  attr :subject_user_picker?, :boolean, default: false
  attr :subject_users, :list, default: []
  attr :admin_submit_flow?, :boolean, default: false

  def new_access_request_form(assigns) do
    ~H"""
    <section class="rounded-box border border-base-300 p-4 bg-base-200/30">
      <h2 class="font-medium mb-3">New request</h2>
      <%= if @applications == [] do %>
        <p class="text-sm text-base-content/70">
          No applications exist yet — seed or create apps before submitting requests.
        </p>
      <% else %>
        <form id="access-request-create" phx-submit="create" class="grid gap-3 max-w-xl">
          <label :if={@subject_user_picker?} class="form-control">
            <span class="label-text text-sm">Access for user</span>
            <select name="subject_user_id" class="select select-bordered w-full" required>
              <option value="">Select user…</option>
              <%= for u <- @subject_users do %>
                <option value={u.id}>{u.name} ({u.email})</option>
              <% end %>
            </select>
            <span class="label-text-alt text-xs text-base-content/60">
              Request is created for this person; you stay the actor in the audit log.
            </span>
          </label>
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
          <label :if={@admin_submit_flow?} class="form-control">
            <span class="label-text text-sm">After submit</span>
            <select name="admin_submit_flow" class="select select-bordered w-full">
              <option value="pending_review" selected>Leave pending — normal review queue</option>
              <option value="approve_immediately">Approve now — queue provisioning (same as review action)</option>
            </select>
            <span class="label-text-alt text-xs text-base-content/60 leading-snug pt-1">
              Requests are always inserted as <span class="font-medium">pending</span>. “Approve now” runs the standard approval operation next so audit entries stay consistent — not a free-form status assignment.
            </span>
          </label>
          <%= if @form_error do %>
            <p class="text-sm text-error">{@form_error}</p>
          <% end %>
          <button type="submit" disabled={not @submit_enabled?} class="btn btn-primary btn-sm disabled:opacity-50">
            Submit request
          </button>
        </form>
      <% end %>
    </section>
    """
  end

  attr :request, :map, required: true

  def access_request_heading(assigns) do
    ~H"""
    <div class="flex gap-4 flex-wrap items-center justify-between">
      <div>
        <p class="text-sm text-base-content/70 mb-1">Access request {@request.id}</p>
        <h1 class="text-2xl font-semibold">{@request.application.slug}</h1>
        <p class="mt-2 text-base-content/80">{@request.reason}</p>
      </div>
      <span class="badge badge-lg badge-outline">{@request.status}</span>
    </div>
    """
  end

  attr :request, :map, required: true

  def access_request_facts(assigns) do
    ~H"""
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
        <dt class="text-base-content/60">{request_reviewer_label(@request)}</dt>
        <dd class="font-medium">
          <%= if @request.reviewed_by do %>
            {@request.reviewed_by.email}
          <% else %>
            —
          <% end %>
        </dd>
      </div>
    </dl>
    """
  end

  attr :grant, :any, default: nil
  attr :show_admin_revoke?, :boolean, default: false

  def access_request_grant_admin_panel(assigns) do
    ~H"""
    <section
      :if={@grant}
      class="rounded-box border border-base-300 p-4 bg-base-200/30 space-y-3"
    >
      <h2 class="font-medium">Grant</h2>
      <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
        <div>
          <dt class="text-base-content/60">Grant ID</dt>
          <dd class="font-mono font-medium">{@grant.id}</dd>
        </div>
        <div>
          <dt class="text-base-content/60">Grant status</dt>
          <dd><span class="badge badge-ghost">{@grant.status}</span></dd>
        </div>
        <div class="sm:col-span-2">
          <dt class="text-base-content/60">External ref</dt>
          <dd class="font-mono text-xs break-all">{@grant.external_ref || "—"}</dd>
        </div>
      </dl>

      <div :if={@grant.status == :active} class="space-y-2">
        <div :if={@show_admin_revoke?} class="flex flex-col gap-2 sm:flex-row sm:items-center sm:flex-wrap">
          <button type="button" phx-click="revoke_grant" phx-value-id={@grant.id} class="btn btn-warning btn-sm">
            Queue revoke
          </button>
          <.link navigate={~p"/grants"} class="btn btn-outline btn-sm">
            Open grants list
          </.link>
          <p class="text-xs text-base-content/60 sm:w-full">
            Revoke removes access for the requester on this application (same workflow as Grants).
          </p>
        </div>
        <p :if={not @show_admin_revoke?} class="text-xs text-base-content/60">
          Admins can queue a revoke from here; reviewers can use the Grants page.
        </p>
      </div>

      <p :if={@grant.status != :active} class="text-sm text-base-content/70">
        Grant status is <span class="font-medium">{@grant.status}</span> — revoke only applies while the grant is active.
      </p>
    </section>
    """
  end

  attr :request, :map, required: true

  def access_request_denial_notice(assigns) do
    ~H"""
    <div :if={@request.status == :denied and @request.denial_reason} class="rounded-box border border-warning/40 bg-warning/10 p-3 text-sm">
      <strong>Denial reason:</strong>
      <span class="ml-2">{@request.denial_reason}</span>
    </div>
    """
  end

  attr :can_review_pending?, :boolean, required: true

  def access_request_review_panel(assigns) do
    ~H"""
    <section
      :if={@can_review_pending?}
      class="rounded-box border border-base-300 p-4 bg-base-200/30 space-y-4"
    >
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
            <textarea name="reason" required minlength="3" class="textarea textarea-bordered textarea-sm"/>
          </label>
          <button type="submit" class="btn btn-error btn-sm w-fit">
            Deny request
          </button>
        </form>
      </div>
    </section>
    """
  end

  attr :request_rows, :list, required: true
  attr :grant_rows, :list, required: true

  def dashboard_snapshot_cards(assigns) do
    ~H"""
    <section>
      <h2 class="font-medium mb-3">Access requests</h2>
      <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <div
          :for={{status, count} <- @request_rows}
          class="rounded-box border border-base-300 bg-base-200/40 p-4"
        >
          <div class="text-xs uppercase text-base-content/60">{status_label(status)}</div>
          <div class="text-2xl font-semibold tabular-nums">{count}</div>
        </div>
      </div>
    </section>

    <section>
      <h2 class="font-medium mb-3">Grants</h2>
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div
          :for={{status, count} <- @grant_rows}
          class="rounded-box border border-base-300 bg-base-200/40 p-4"
        >
          <div class="text-xs uppercase text-base-content/60">{status_label(status)}</div>
          <div class="text-2xl font-semibold tabular-nums">{count}</div>
        </div>
      </div>
    </section>
    """
  end

  defp request_reviewer_label(%{status: :denied}), do: "Denied by"
  defp request_reviewer_label(%{status: :pending}), do: "Reviewer"
  defp request_reviewer_label(_), do: "Approved by"

  defp reviewer_action_hint(:denied), do: "denied"
  defp reviewer_action_hint(_), do: "approved"

  defp format_occurred_at(nil), do: "—"

  defp format_occurred_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp actor_email_or_id(nil), do: "—"
  defp actor_email_or_id(%{email: email}) when is_binary(email), do: email
  defp actor_email_or_id(user), do: inspect(user.id)

  defp format_entity_ref(type, id) when is_binary(type), do: type <> "##{id}"

  defp format_entity_ref(type, id) when is_atom(type),
    do: Atom.to_string(type) <> "##{id}"

  defp status_label(atom) when is_atom(atom), do: Atom.to_string(atom)
end
