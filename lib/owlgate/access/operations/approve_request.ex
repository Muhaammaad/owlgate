defmodule OwlGate.Access.Operations.ApproveRequest do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessRequest, Constants, Guards, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Policy.AccessPolicy
  alias OwlGate.Repo

  @review_status :approved

  def run(%User{} = actor, request_id) do
    with true <- AccessPolicy.can_review?(actor) || {:error, :forbidden},
         {:ok, request} <- QueryHelpers.fetch_request(request_id),
         {:ok, application} <-
           QueryHelpers.fetch_application(%{"application_id" => request.application_id}),
         :ok <- Guards.ensure_pending(request),
         :ok <- Guards.prevent_self_approval(actor, request),
         :ok <- Guards.ensure_high_risk_approval(actor, application) do
      review_with_audit(actor.id, request)
    end
  end

  defp review_with_audit(actor_id, request) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.update(
      :request,
      AccessRequest.review_changeset(request, %{
        status: @review_status,
        reviewed_by_id: actor_id,
        reviewed_at: now
      })
    )
    |> Multi.run(:audit, fn _repo, %{request: updated} ->
      Audit.log(
        actor_id,
        "access_request.approved",
        Constants.entity_access_request(),
        updated.id,
        %{
          application_id: updated.application_id,
          user_id: updated.user_id
        }
      )
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:request)
  end
end
