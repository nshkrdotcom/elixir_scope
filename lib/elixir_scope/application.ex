defmodule ElixirScope.Application do
  @moduledoc """
  ElixirScope Application Supervisor
  Manages the lifecycle of all ElixirScope components in a supervised manner.
  The supervision tree is designed to be fault-tolerant and to restart
  components in the correct order if failures occur.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting ElixirScope application...")

    base_children = [
      # Foundation Layer Services
      # Registry must start first for service discovery
      {ElixirScope.Foundation.ProcessRegistry, []},

      # Core foundation services with production namespace
      {ElixirScope.Foundation.Services.ConfigServer, [namespace: :production]},
      {ElixirScope.Foundation.Services.EventStore, [namespace: :production]},
      {ElixirScope.Foundation.Services.TelemetryService, [namespace: :production]},

      # Infrastructure protection components
      {ElixirScope.Foundation.Infrastructure.ConnectionManager, []},
      {ElixirScope.Foundation.Infrastructure.RateLimiter.HammerBackend,
       [clean_period: :timer.minutes(1)]},

      # Task supervisor for dynamic tasks
      {Task.Supervisor, name: ElixirScope.Foundation.TaskSupervisor}

      # Future layers will be added here:
      # Layer 1: Core capture pipeline will be added here
      # {ElixirScope.Capture.PipelineManager, []},
      # Layer 2: Storage and correlation will be added here
      # {ElixirScope.Storage.QueryCoordinator, []},
      # Layer 4: AI components will be added here
      # {ElixirScope.AI.Orchestrator, []},
    ]

    children = base_children ++ test_children()

    opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("ElixirScope application started successfully")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start ElixirScope application: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping ElixirScope application...")
    :ok
  end

  # Private function to add test-specific children
  defp test_children do
    if Application.get_env(:elixir_scope, :test_mode, false) do
      [{ElixirScope.TestSupport.TestSupervisor, []}]
    else
      []
    end
  end
end
