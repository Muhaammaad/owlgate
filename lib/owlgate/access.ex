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

  @doc "Lists all managed applications."
  def list_applications, do: Repo.all(Application)

  @doc "Gets an application by id and raises if missing."
  def get_application!(id), do: Repo.get!(Application, id)

  @doc "Creates an application with normalized slug fields."
  def create_application(attrs) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Aggregate counts by access request status and grant status for operator dashboards.
  """
  @spec dashboard_snapshot() :: %{requests: map(), grants: map()}
  def dashboard_snapshot do
    request_rows =
      AccessRequest
      |> group_by([r], r.status)
      |> select([r], {r.status, count(r.id)})
      |> Repo.all()

    grant_rows =
      AccessGrant
      |> group_by([g], g.status)
      |> select([g], {g.status, count(g.id)})
      |> Repo.all()

    requests =
      Constants.request_statuses()
      |> Enum.map(&{&1, 0})
      |> Map.new()
      |> then(&Map.merge(&1, Map.new(request_rows)))

    grants =
      Constants.grant_statuses()
      |> Enum.map(&{&1, 0})
      |> Map.new()
      |> then(&Map.merge(&1, Map.new(grant_rows)))

    %{requests: requests, grants: grants}
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
