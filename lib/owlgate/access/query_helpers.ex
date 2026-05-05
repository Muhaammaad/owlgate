defmodule OwlGate.Access.QueryHelpers do
  @moduledoc false

  import Ecto.Query, warn: false

  alias OwlGate.Access.{AccessGrant, AccessRequest, Application}
  alias OwlGate.Access.Constants
  alias OwlGate.Repo

  def fetch_application(%{"application_id" => id}) do
    case Repo.get(Application, id) do
      %Application{active: true} = application -> {:ok, application}
      %Application{} -> {:error, :inactive_application}
      nil -> {:error, :not_found}
    end
  end

  def fetch_request(id) do
    case Repo.get(AccessRequest, id) do
      nil -> {:error, :not_found}
      request -> {:ok, request}
    end
  end

  def fetch_grant(id) do
    case Repo.get(AccessGrant, id) do
      nil -> {:error, :not_found}
      grant -> {:ok, grant}
    end
  end

  def has_open_request?(user_id, app_id) do
    Repo.exists?(
      from r in AccessRequest,
        where:
          r.user_id == ^user_id and r.application_id == ^app_id and
            r.status in ^Constants.request_open_statuses()
    )
  end

  def has_active_grant?(user_id, app_id) do
    Repo.exists?(
      from g in AccessGrant,
        where: g.user_id == ^user_id and g.application_id == ^app_id and g.status == :active
    )
  end
end
