defmodule OwlGate.Access.Operations.CreateRequest do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessRequest, Constants, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Policy.AccessPolicy
  alias OwlGate.Repo

  def run(%User{} = actor, attrs) do
    with {:ok, application} <- QueryHelpers.fetch_application(attrs),
         true <- AccessPolicy.can_request?(actor, application) || {:error, :forbidden},
         :ok <- forbid_open_request(actor.id, application.id),
         :ok <- forbid_active_grant(actor.id, application.id) do
      attrs
      |> enrich_attrs(actor.id, application.id)
      |> insert_with_audit(actor.id)
    end
  end

  defp forbid_open_request(user_id, application_id) do
    if QueryHelpers.has_open_request?(user_id, application_id),
      do: {:error, :duplicate_request},
      else: :ok
  end

  defp forbid_active_grant(user_id, application_id) do
    if QueryHelpers.has_active_grant?(user_id, application_id),
      do: {:error, :already_has_active_grant},
      else: :ok
  end

  defp enrich_attrs(attrs, actor_id, application_id) do
    attrs
    |> Map.put("user_id", actor_id)
    |> Map.put("application_id", application_id)
    |> Map.put_new("request_token", Ecto.UUID.generate())
  end

  defp insert_with_audit(attrs, actor_id) do
    Multi.new()
    |> Multi.insert(:request, AccessRequest.create_changeset(%AccessRequest{}, attrs))
    |> Multi.run(:audit, fn _repo, %{request: request} ->
      Audit.log(
        actor_id,
        "access_request.created",
        Constants.entity_access_request(),
        request.id,
        %{
          application_id: request.application_id,
          user_id: request.user_id
        }
      )
    end)
    |> Repo.transaction()
    |> OperationResult.from_transaction(:request)
  end
end
