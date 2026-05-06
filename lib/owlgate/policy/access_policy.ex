defmodule OwlGate.Policy.AccessPolicy do
  @moduledoc """
  Authorization and policy checks for access lifecycle.

  ## Examples

      iex> alias OwlGate.{Accounts.User, Access.Application, Policy.AccessPolicy}
      iex> actor = %User{id: 1, role: :manager}
      iex> requester = %User{id: 2, role: :employee}
      iex> app = %Application{active: true, risk_level: :low}
      iex> AccessPolicy.can_request?(actor, app)
      true
      iex> AccessPolicy.can_self_approve?(actor, requester)
      true
      iex> AccessPolicy.can_self_approve?(actor, %User{id: 1})
      false
  """

  alias OwlGate.Access.Application
  alias OwlGate.Accounts.User

  @doc "Whether a user can request access for the application."
  def can_request?(%User{role: role}, %Application{active: true}) when role in [:employee, :manager, :admin],
    do: true

  def can_request?(_, _), do: false

  @doc "Whether a user can review pending access requests."
  def can_review?(%User{role: role}) when role in [:manager, :admin], do: true
  def can_review?(_), do: false

  @doc """
  Returns true when the reviewer and requester are different users.

  Naming follows the guard \"prevent self-approval\": when this returns false, the actor must not approve.
  """
  def can_self_approve?(%User{id: actor_id}, %User{id: requester_id}), do: actor_id != requester_id

  @doc "High-risk apps require owner/admin review."
  def requires_app_owner_approval?(%Application{risk_level: :high}), do: true
  def requires_app_owner_approval?(_), do: false

  @doc """
  When true, operator lists (requests, grants, dashboard counts, audit feed)
  are limited to the signed-in user's own records.

  Managers and admins keep cross-user visibility for review and revoke workflows.
  """
  def employee_data_scope?(%User{role: :employee}), do: true
  def employee_data_scope?(_), do: false

  @doc "Who can approve requests for high-risk applications."
  def can_review_high_risk?(%User{role: :admin}, _application), do: true
  def can_review_high_risk?(%User{id: actor_id}, %Application{owner_id: owner_id}), do: actor_id == owner_id
  def can_review_high_risk?(_, _), do: false
end

