defmodule OwlGate.Access.Operations.ActivateGrant do
  @moduledoc false

  alias Ecto.Multi

  alias OwlGate.Access.{
    AccessGrant,
    AccessRequest,
    Constants,
    Guards,
    OperationResult,
    QueryHelpers
  }

  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Repo

  @request_to_status :provisioned

  def run(%User{} = actor, request_id, external_ref) do
    with {:ok, request} <- QueryHelpers.fetch_request(request_id),
         :ok <- Guards.ensure_status(request, :provisioning),
         {:ok, application} <-
           QueryHelpers.fetch_application(%{"application_id" => request.application_id}) do
      activate_with_audit(actor.id, request, application.id, external_ref)
    end
  end

  defp activate_with_audit(actor_id, request, application_id, external_ref) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Multi.new()
    |> Multi.update(
      :request,
      AccessRequest.status_changeset(request, %{status: @request_to_status})
    )
    |> Multi.insert(
      :grant,
      AccessGrant.create_changeset(%AccessGrant{}, %{
        user_id: request.user_id,
        application_id: application_id,
        granted_by_id: actor_id,
        access_request_id: request.id,
        external_ref: external_ref,
        granted_at: now
      })
    )
    |> Multi.run(:audit, fn _repo, %{grant: grant} ->
      Audit.log(actor_id, "access_grant.activated", Constants.entity_access_grant(), grant.id, %{
        access_request_id: request.id,
        user_id: request.user_id
      })
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:grant)
  end
end
