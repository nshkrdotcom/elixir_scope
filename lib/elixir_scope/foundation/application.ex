defmodule ElixirScope.Foundation.Application do
  @moduledoc """
  Main application module for ElixirScope Foundation layer.

  Starts and supervises all the core Foundation services in the proper order.
  Now includes ProcessRegistry for namespace isolation and TestSupervisor
  for test isolation support.

  This application follows the OTP supervision principles and ensures
  graceful startup and shutdown of all Foundation layer components.

  ## Supervision Tree

  1. ProcessRegistry - Must start first for service discovery
  2. Core foundation services (ConfigServer, EventStore, TelemetryService)
  3. TestSupervisor - For dynamic test isolation
  4. Task.Supervisor - For dynamic tasks

  ## Examples

      # Started automatically by the application framework
      # Or manually for testing:
      iex> {:ok, _pid} = ElixirScope.Foundation.Application.start(:normal, [])
  """

  use Application

  @typedoc "Application start type"
  @type start_type :: :normal | :takeover | :failover

  @typedoc "Application arguments"
  @type start_args :: term()

  @impl Application
  @spec start(start_type(), start_args()) :: {:ok, pid()} | {:error, term()}
  def start(_type, _args) do
    children = [
      # Registry must start first for service discovery
      {ElixirScope.Foundation.ProcessRegistry, []},

      # Core foundation services with production namespace
      {ElixirScope.Foundation.Services.ConfigServer, [namespace: :production]},
      {ElixirScope.Foundation.Services.EventStore, [namespace: :production]},
      {ElixirScope.Foundation.Services.TelemetryService, [namespace: :production]},

      # TestSupervisor for dynamic test isolation
      {ElixirScope.Foundation.TestSupervisor, []},

      # Task supervisor for dynamic tasks
      {Task.Supervisor, name: ElixirScope.Foundation.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ElixirScope.Foundation.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  @spec stop(term()) :: :ok
  def stop(_state) do
    :ok
  end
end
