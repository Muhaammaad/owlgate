defmodule OwlGate.Connectors.Dispatcher do
  @moduledoc """
  Routes provisioning/revocation calls to the configured adapter.
  """

  alias OwlGate.Connectors.MockProvider

  @default_adapter MockProvider

  @spec provision(map()) :: {:ok, map()} | {:error, term()}
  def provision(payload), do: adapter().provision(payload)

  @spec revoke(map()) :: {:ok, map()} | {:error, term()}
  def revoke(payload), do: adapter().revoke(payload)

  defp adapter do
    Application.get_env(:owlgate, :connector_adapter, @default_adapter)
  end
end
