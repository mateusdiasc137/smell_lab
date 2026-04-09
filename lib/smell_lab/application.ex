defmodule SmellLab.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmellLabWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:smell_lab, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SmellLab.PubSub},
      # Start a worker by calling: SmellLab.Worker.start_link(arg)
      # {SmellLab.Worker, arg},
      SmellLab.Retrieval.Index,
      # Start to serve requests, typically the last entry
      SmellLabWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SmellLab.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SmellLabWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
