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
  def can_request?(%User{role: role}, %Application{active: true})
      when role in [:employee, :manager, :admin],
      do: true

  def can_request?(_, _), do: false

  @doc "Whether a user can review pending access requests."
  def can_review?(%User{role: role}) when role in [:manager, :admin], do: true
  def can_review?(_), do: false

  @doc "Prevents requesters from approving their own requests."
  def can_self_approve?(%User{id: actor_id}, %User{id: requester_id}),
    do: actor_id != requester_id

  @doc "High-risk apps require owner/admin review."
  def requires_app_owner_approval?(%Application{risk_level: :high}), do: true
  def requires_app_owner_approval?(_), do: false

  @doc "Who can approve requests for high-risk applications."
  def can_review_high_risk?(%User{role: :admin}, _application), do: true

  def can_review_high_risk?(%User{id: actor_id}, %Application{owner_id: owner_id}),
    do: actor_id == owner_id

  def can_review_high_risk?(_, _), do: false
end
