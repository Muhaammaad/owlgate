defmodule OwlGate.Access.Operations.DenyRequest do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessRequest, Constants, Guards, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Policy.AccessPolicy
  alias OwlGate.Repo

  @review_status :denied

  def run(%User{} = actor, request_id, reason) do
    with :ok <- validate_reason(reason),
         true <- AccessPolicy.can_review?(actor) || {:error, :forbidden},
         {:ok, request} <- QueryHelpers.fetch_request(request_id),
         :ok <- Guards.ensure_pending(request),
         :ok <- Guards.prevent_self_approval(actor, request) do
      deny_with_audit(actor.id, request, reason)
    end
  end

  defp deny_with_audit(actor_id, request, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.update(
      :request,
      AccessRequest.review_changeset(request, %{
        status: @review_status,
        reviewed_by_id: actor_id,
        reviewed_at: now,
        denial_reason: reason
      })
    )
    |> Multi.run(:audit, fn _repo, %{request: updated} ->
      Audit.log(
        actor_id,
        "access_request.denied",
        Constants.entity_access_request(),
        updated.id,
        %{
          application_id: updated.application_id,
          user_id: updated.user_id,
          reason: reason
        }
      )
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:request)
  end

  defp validate_reason(reason) when is_binary(reason) do
    if String.trim(reason) == "", do: {:error, :denial_reason_required}, else: :ok
  end

  defp validate_reason(_), do: {:error, :denial_reason_required}
end
