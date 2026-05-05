defmodule OwlGate.Connectors.MockProvider do
  @moduledoc """
  Mock connector for local and CI flows.

  Supports simulated failure by passing `"simulate_failure" => true`.
  """

  @behaviour OwlGate.Connectors.Adapter

  @impl true
  def provision(%{"simulate_failure" => true}), do: {:error, :simulated_provision_failure}

  def provision(%{"request_id" => request_id}) do
    {:ok,
     %{
       external_ref: "mock-access-#{request_id}",
       provisioned_at: DateTime.utc_now() |> DateTime.truncate(:second)
     }}
  end

  @impl true
  def revoke(%{"simulate_failure" => true}), do: {:error, :simulated_revoke_failure}

  def revoke(%{"grant_id" => grant_id}) do
    {:ok,
     %{
       external_ref: "mock-revoked-#{grant_id}",
       revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)
     }}
  end
end
