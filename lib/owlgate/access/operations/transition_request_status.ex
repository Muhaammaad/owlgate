defmodule OwlGate.Access.Operations.TransitionRequestStatus do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessRequest, Constants, Guards, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Repo

  def run(%User{} = actor, request_id, from_status, to_status, action) do
    with {:ok, request} <- QueryHelpers.fetch_request(request_id),
         :ok <- Guards.ensure_status(request, from_status) do
      transition_with_audit(actor.id, request, to_status, action)
    end
  end

  defp transition_with_audit(actor_id, request, to_status, action) do
    Multi.new()
    |> Multi.update(:request, AccessRequest.status_changeset(request, %{status: to_status}))
    |> Multi.run(:audit, fn _repo, %{request: updated} ->
      Audit.log(actor_id, action, Constants.entity_access_request(), updated.id, %{
        status: Atom.to_string(to_status)
      })
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:request)
  end
end
