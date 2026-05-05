defmodule OwlGate.Access do
  @moduledoc """
  Public access lifecycle facade.

  Keeps external API stable while delegating each lifecycle action to focused operation modules.
  """

  alias OwlGate.Access.Application

  alias OwlGate.Access.Operations.{
    ActivateGrant,
    ApproveRequest,
    CreateRequest,
    DenyRequest,
    RequestRevoke,
    TransitionGrantStatus,
    TransitionRequestStatus
  }

  alias OwlGate.Accounts.User
  alias OwlGate.Access.{AccessGrant, AccessRequest, Constants}
  alias OwlGate.Workers.{ProvisionAccessJob, RevokeAccessJob}
  alias OwlGate.Repo

  import Ecto.Query

  @type domain_error ::
          :not_found
          | :forbidden
          | :invalid_status
          | :duplicate_request
          | :already_has_active_grant
          | :self_approval_not_allowed
          | :high_risk_requires_owner_or_admin
          | :inactive_application
          | :denial_reason_required

  @doc "Lists all managed applications with owner preloaded."
  def list_applications do
    Application
    |> preload(:owner)
    |> order_by([a], asc: a.name)
    |> Repo.all()
  end

  @doc "Gets an application by id and raises if missing."
  def get_application!(id) do
    Application
    |> Repo.get!(id)
    |> Repo.preload(:owner)
  end

  @doc "Fetches one application or `{:error, :not_found}`."
  def fetch_application(id) do
    case Repo.get(Application, id) do
      nil -> {:error, :not_found}
      app -> {:ok, Repo.preload(app, :owner)}
    end
  end

  @doc "Creates an application with normalized slug fields."
  def create_application(attrs) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an application."
  def update_application(%Application{} = application, attrs) do
    application
    |> Application.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes an application."
  def delete_application(%Application{} = application), do: Repo.delete(application)

  def change_application(application, attrs \\ %{})

  def change_application(%Application{id: nil} = application, attrs) do
    Application.form_changeset(application, attrs)
  end

  def change_application(%Application{} = application, attrs) do
    Application.changeset(application, attrs)
  end

  @doc """
  Aggregate counts by access request status and grant status for operator dashboards.
  """
  @spec dashboard_snapshot() :: %{requests: map(), grants: map()}
  def dashboard_snapshot do
    %{
      requests: counts_for_status(AccessRequest, Constants.request_statuses()),
      grants: counts_for_status(AccessGrant, Constants.grant_statuses())
    }
  end

  defp counts_for_status(queryable, statuses) do
    rows =
      queryable
      |> group_by([r], r.status)
      |> select([r], {r.status, count(r.id)})
      |> Repo.all()

    statuses
    |> Enum.map(&{&1, 0})
    |> Map.new()
    |> Map.merge(Map.new(rows))
  end

  @doc "Lists access requests with related users and applications."
  def list_access_requests(opts \\ []) do
    status = Keyword.get(opts, :status)

    AccessRequest
    |> order_by(desc: :inserted_at)
    |> maybe_filter_requests(status)
    |> preload([:user, :application, :reviewed_by])
    |> Repo.all()
  end

  defp maybe_filter_requests(query, nil), do: query

  defp maybe_filter_requests(query, status) when is_atom(status) do
    where(query, [r], r.status == ^status)
  end

  @doc "Loads a single access request with associations or returns `:not_found`."
  def fetch_access_request(id) do
    case Repo.get(AccessRequest, id) do
      nil -> {:error, :not_found}
      request -> {:ok, Repo.preload(request, [:user, :application, :reviewed_by])}
    end
  end

  @doc """
  Lists access grants with holders, apps, and originating request references.
  """
  def list_grants(opts \\ []) do
    status = Keyword.get(opts, :status)

    AccessGrant
    |> order_by(desc: :updated_at)
    |> maybe_filter_grants(status)
    |> preload([:user, :application, :access_request])
    |> Repo.all()
  end

  defp maybe_filter_grants(query, nil), do: query

  defp maybe_filter_grants(query, status) when is_atom(status) do
    where(query, [g], g.status == ^status)
  end

  @doc "Loads one grant preloaded or `{:error, :not_found}`."
  def fetch_grant(id) do
    case Repo.get(AccessGrant, id) do
      nil -> {:error, :not_found}
      grant -> {:ok, Repo.preload(grant, [:user, :application, :access_request, :granted_by])}
    end
  end

  @doc """
  Creates an access request for the actor if policy and dedupe checks pass.
  """
  def create_request(%User{} = actor, attrs), do: CreateRequest.run(actor, attrs)

  @doc "Approves a pending request after policy and risk checks."
  def approve_request(%User{} = actor, request_id) do
    with {:ok, request} <- ApproveRequest.run(actor, request_id),
         {:ok, _job} <- enqueue_provision_job(actor.id, request.id) do
      {:ok, request}
    end
  end

  @doc "Denies a pending request."
  def deny_request(%User{} = actor, request_id, reason \\ nil),
    do: DenyRequest.run(actor, request_id, reason)

  @doc "Transitions approved request into provisioning state."
  def mark_provisioning(%User{} = actor, request_id),
    do:
      TransitionRequestStatus.run(
        actor,
        request_id,
        :approved,
        :provisioning,
        "access_request.provisioning"
      )

  @doc "Creates an active grant for a provisioning request."
  def activate_grant(%User{} = actor, request_id, external_ref \\ nil),
    do: ActivateGrant.run(actor, request_id, external_ref)

  @doc "Marks an active grant for async revoke processing."
  def request_revoke(%User{} = actor, grant_id) do
    with {:ok, grant} <- RequestRevoke.run(actor, grant_id),
         {:ok, _job} <- enqueue_revoke_job(actor.id, grant.id) do
      {:ok, grant}
    end
  end

  @doc "Finalizes grant revoke transition."
  def complete_revoke(%User{} = actor, grant_id),
    do: TransitionGrantStatus.run(actor, grant_id, :revoking, :revoked, "access_grant.revoked")

  @doc "Marks provisioning as failed."
  def fail_request(%User{} = actor, request_id),
    do:
      TransitionRequestStatus.run(
        actor,
        request_id,
        :provisioning,
        :failed,
        "access_request.failed"
      )

  @doc false
  def enqueue_provision_job(actor_id, request_id, opts \\ %{}) do
    args =
      %{
        "actor_id" => actor_id,
        "request_id" => request_id
      }
      |> Map.merge(opts)

    args
    |> ProvisionAccessJob.new()
    |> Oban.insert()
  end

  @doc false
  def enqueue_revoke_job(actor_id, grant_id, opts \\ %{}) do
    args =
      %{
        "actor_id" => actor_id,
        "grant_id" => grant_id
      }
      |> Map.merge(opts)

    args
    |> RevokeAccessJob.new()
    |> Oban.insert()
  end
end
