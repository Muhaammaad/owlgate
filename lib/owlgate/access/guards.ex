defmodule OwlGate.Access.Guards do
  @moduledoc false

  alias OwlGate.Access.{AccessGrant, AccessRequest, Application}
  alias OwlGate.Accounts.User
  alias OwlGate.Policy.AccessPolicy

  def ensure_pending(%AccessRequest{status: :pending}), do: :ok
  def ensure_pending(_), do: {:error, :invalid_status}

  def ensure_status(%AccessRequest{status: status}, status), do: :ok
  def ensure_status(_, _), do: {:error, :invalid_status}

  def ensure_grant_status(%AccessGrant{status: status}, status), do: :ok
  def ensure_grant_status(_, _), do: {:error, :invalid_status}

  def prevent_self_approval(%User{} = actor, %AccessRequest{user_id: requester_id}) do
    requester = %User{id: requester_id}

    if AccessPolicy.can_self_approve?(actor, requester),
      do: :ok,
      else: {:error, :self_approval_not_allowed}
  end

  def ensure_high_risk_approval(%User{} = actor, %Application{} = app) do
    if AccessPolicy.requires_app_owner_approval?(app) and
         not AccessPolicy.can_review_high_risk?(actor, app) do
      {:error, :high_risk_requires_owner_or_admin}
    else
      :ok
    end
  end
end
