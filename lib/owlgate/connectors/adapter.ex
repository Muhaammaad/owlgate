defmodule OwlGate.Connectors.Adapter do
  @moduledoc """
  Behavior for external provisioning/revocation connectors.
  """

  @callback provision(map()) :: {:ok, map()} | {:error, term()}
  @callback revoke(map()) :: {:ok, map()} | {:error, term()}
end
