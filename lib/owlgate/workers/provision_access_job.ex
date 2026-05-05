defmodule OwlGate.Workers.ProvisionAccessJob do
  @moduledoc """
  Async provisioning worker.
  """

  use Oban.Worker,
    queue: :provisioning,
    max_attempts: 10,
    unique: [period: 300, fields: [:worker, :args], keys: [:request_id]]

  alias OwlGate.Access
  alias OwlGate.Accounts
  alias OwlGate.Connectors.Dispatcher

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"actor_id" => actor_id, "request_id" => request_id} = args}) do
    actor = Accounts.get_user!(actor_id)

    with {:ok, _request} <- Access.mark_provisioning(actor, request_id),
         {:ok, result} <- Dispatcher.provision(args),
         {:ok, _grant} <-
           Access.activate_grant(
             actor,
             request_id,
             result["external_ref"] || result[:external_ref]
           ) do
      :ok
    else
      {:error, _reason} = error ->
        _ = Access.fail_request(actor, request_id)
        error
    end
  end
end
