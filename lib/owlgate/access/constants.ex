defmodule OwlGate.Access.Constants do
  @moduledoc """
  Central constants for access lifecycle transitions and audit entity names.

  ## Examples

      iex> OwlGate.Access.Constants.request_statuses()
      [:pending, :approved, :denied, :provisioning, :provisioned, :failed]

      iex> OwlGate.Access.Constants.grant_statuses()
      [:active, :revoking, :revoked, :failed]

      iex> :pending in OwlGate.Access.Constants.request_open_statuses()
      true

      iex> OwlGate.Access.Constants.entity_access_request()
      "access_request"
  """

  @request_open_statuses [:pending, :approved, :provisioning]
  @request_statuses [:pending, :approved, :denied, :provisioning, :provisioned, :failed]
  @grant_statuses [:active, :revoking, :revoked, :failed]
  @entity_access_request "access_request"
  @entity_access_grant "access_grant"

  @spec request_open_statuses() :: [atom()]
  def request_open_statuses, do: @request_open_statuses

  @spec request_statuses() :: [atom()]
  def request_statuses, do: @request_statuses

  @spec grant_statuses() :: [atom()]
  def grant_statuses, do: @grant_statuses

  @spec entity_access_request() :: String.t()
  def entity_access_request, do: @entity_access_request

  @spec entity_access_grant() :: String.t()
  def entity_access_grant, do: @entity_access_grant
end
