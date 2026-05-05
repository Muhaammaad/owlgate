defmodule OwlGate.Access.Operations.TransitionGrantStatus do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessGrant, Constants, Guards, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Repo

  def run(%User{} = actor, grant_id, from_status, to_status, action) do
    with {:ok, grant} <- QueryHelpers.fetch_grant(grant_id),
         :ok <- Guards.ensure_grant_status(grant, from_status) do
      transition_with_audit(actor.id, grant, to_status, action)
    end
  end

  defp transition_with_audit(actor_id, grant, to_status, action) do
    Multi.new()
    |> Multi.update(:grant, AccessGrant.status_changeset(grant, %{status: to_status}))
    |> Multi.run(:audit, fn _repo, %{grant: updated} ->
      Audit.log(actor_id, action, Constants.entity_access_grant(), updated.id, %{
        status: Atom.to_string(to_status)
      })
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:grant)
  end
end
