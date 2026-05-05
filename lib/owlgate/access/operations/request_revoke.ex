defmodule OwlGate.Access.Operations.RequestRevoke do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessGrant, Constants, Guards, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Policy.AccessPolicy
  alias OwlGate.Repo

  @grant_status :revoking

  def run(%User{} = actor, grant_id) do
    with true <- AccessPolicy.can_review?(actor) || {:error, :forbidden},
         {:ok, grant} <- QueryHelpers.fetch_grant(grant_id),
         :ok <- Guards.ensure_grant_status(grant, :active) do
      mark_revoking_with_audit(actor.id, grant)
    end
  end

  defp mark_revoking_with_audit(actor_id, grant) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.update(
      :grant,
      AccessGrant.status_changeset(grant, %{status: @grant_status, revoked_at: now})
    )
    |> Multi.run(:audit, fn _repo, %{grant: updated} ->
      Audit.log(actor_id, "access_grant.revoking", Constants.entity_access_grant(), updated.id, %{
        user_id: updated.user_id,
        application_id: updated.application_id
      })
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:grant)
  end
end
