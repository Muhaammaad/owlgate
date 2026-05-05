defmodule OwlGate.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OwlGateWeb.Telemetry,
      OwlGate.Repo,
      {Oban, Application.fetch_env!(:owlgate, Oban)},
      {DNSCluster, query: Application.get_env(:owlgate, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OwlGate.PubSub},
      # Start a worker by calling: OwlGate.Worker.start_link(arg)
      # {OwlGate.Worker, arg},
      # Start to serve requests, typically the last entry
      OwlGateWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OwlGate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OwlGateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
