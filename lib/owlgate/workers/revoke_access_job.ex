defmodule OwlGate.Workers.RevokeAccessJob do
  @moduledoc """
  Async revoke worker.
  """

  use Oban.Worker,
    queue: :revocations,
    max_attempts: 10,
    unique: [period: 300, fields: [:worker, :args], keys: [:grant_id]]

  alias OwlGate.Access
  alias OwlGate.Accounts
  alias OwlGate.Connectors.Dispatcher

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"actor_id" => actor_id, "grant_id" => grant_id} = args}) do
    actor = Accounts.get_user!(actor_id)

    with {:ok, _grant} <- Dispatcher.revoke(args),
         {:ok, _grant} <- Access.complete_revoke(actor, grant_id) do
      :ok
    end
  end
end
