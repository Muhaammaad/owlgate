defmodule OwlGate.Access.Operations.CreateRequest do
  @moduledoc false

  alias Ecto.Multi
  alias OwlGate.Access.{AccessRequest, Constants, OperationResult, QueryHelpers}
  alias OwlGate.Accounts.User
  alias OwlGate.Audit
  alias OwlGate.Policy.{AccessPolicy, AdminPolicy}
  alias OwlGate.Repo

  def run(%User{} = actor, attrs) do
    with {:ok, application} <- QueryHelpers.fetch_application(attrs),
         {:ok, subject_user} <- resolve_subject_user(actor, attrs),
         true <- AccessPolicy.can_request?(actor, application) || {:error, :forbidden},
         true <- AccessPolicy.can_request?(subject_user, application) || {:error, :forbidden},
         :ok <- forbid_open_request(subject_user.id, application.id),
         :ok <- forbid_active_grant(subject_user.id, application.id) do
      attrs
      |> enrich_attrs(subject_user.id, application.id)
      |> insert_with_audit(actor.id)
    end
  end

  defp resolve_subject_user(%User{} = actor, attrs) do
    cond do
      AdminPolicy.admin?(actor) ->
        raw = attrs["subject_user_id"] || attrs[:subject_user_id]

        case parse_positive_int(raw) do
          {:ok, id} ->
            case Repo.get(User, id) do
              nil -> {:error, :subject_user_not_found}
              %User{} = u -> {:ok, u}
            end

          :error ->
            {:error, :subject_user_required}
        end

      true ->
        {:ok, actor}
    end
  end

  defp parse_positive_int(nil), do: :error
  defp parse_positive_int(""), do: :error

  defp parse_positive_int(raw) when is_binary(raw) do
    raw |> String.trim() |> Integer.parse() |> do_parse_result()
  end

  defp parse_positive_int(raw) when is_integer(raw) and raw > 0, do: {:ok, raw}
  defp parse_positive_int(_), do: :error

  defp do_parse_result({id, rest}) when id > 0 and rest == "", do: {:ok, id}
  defp do_parse_result(_), do: :error

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

  defp enrich_attrs(attrs, subject_user_id, application_id) do
    attrs
    |> Map.put("user_id", subject_user_id)
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
