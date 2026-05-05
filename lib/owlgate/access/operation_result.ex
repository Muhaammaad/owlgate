defmodule OwlGate.Access.OperationResult do
  @moduledoc false

  def from_transaction({:ok, changes}, key), do: {:ok, Map.fetch!(changes, key)}
  def from_transaction({:error, _step, reason, _changes}, _key), do: {:error, reason}
end
