defmodule OwlGate.Notifications.Access do
  @moduledoc """
  Notification hooks for access lifecycle events.

  Current implementation is intentionally no-op so domain flows can invoke
  these hooks without coupling to a mail provider yet.
  """

  @spec request_created(integer()) :: :ok
  def request_created(_request_id), do: :ok

  @spec request_approved(integer()) :: :ok
  def request_approved(_request_id), do: :ok

  @spec request_denied(integer()) :: :ok
  def request_denied(_request_id), do: :ok

  @spec request_provisioned(integer()) :: :ok
  def request_provisioned(_request_id), do: :ok
end
