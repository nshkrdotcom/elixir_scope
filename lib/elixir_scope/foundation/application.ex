defmodule ElixirScope.Foundation.Application do
  @moduledoc """
  Main application module for ElixirScope Foundation layer.

  Starts and supervises all the core Foundation services in the proper order.
  """

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      # Core foundation services
      {ElixirScope.Foundation.Services.ConfigServer,
       name: ElixirScope.Foundation.Services.ConfigServer},
      {ElixirScope.Foundation.Services.EventStore,
       name: ElixirScope.Foundation.Services.EventStore},
      {ElixirScope.Foundation.Services.TelemetryService,
       name: ElixirScope.Foundation.Services.TelemetryService},

      # Task supervisor for dynamic tasks
      {Task.Supervisor, name: ElixirScope.Foundation.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ElixirScope.Foundation.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# defmodule ElixirScope.Foundation.Application do
#   @moduledoc """
#   Application module for ElixirScope Foundation layer.

#   Manages the lifecycle of Foundation layer components and ensures
#   proper initialization order.
#   """

#   use Application
#   require Logger

#   alias ElixirScope.Foundation.{Config, Events, Telemetry, ErrorContext}

#   @impl Application
#   def start(_type, _args) do
#     Logger.info("Starting ElixirScope Foundation Application")

#     context = ErrorContext.new(__MODULE__, :start)

#     children = [
#       # Configuration must start first
#       {Config, []}

#       # Add other supervised processes here as needed
#       # Note: Events and Telemetry are currently stateless and don't need supervision
#     ]

#     opts = [strategy: :one_for_one, name: ElixirScope.Foundation.Supervisor]

#     case ErrorContext.with_context(context, fn ->
#            Supervisor.start_link(children, opts)
#          end) do
#       {:ok, _pid} = result ->
#         # Initialize stateless components after supervision tree is up
#         case initialize_stateless_components() do
#           :ok ->
#             Logger.info("ElixirScope Foundation Application started successfully")
#             result

#           {:error, error} ->
#             Logger.error("Failed to initialize stateless components: #{inspect(error)}")
#             {:error, error}
#         end

#       {:error, reason} = error ->
#         Logger.error("Failed to start ElixirScope Foundation Application: #{inspect(reason)}")
#         error
#     end
#   end

#   @impl Application
#   def stop(_state) do
#     Logger.info("Stopping ElixirScope Foundation Application")
#     :ok
#   end

#   @spec initialize_stateless_components() :: :ok | {:error, term()}
#   defp initialize_stateless_components do
#     context = ErrorContext.new(__MODULE__, :initialize_stateless_components)

#     ErrorContext.with_context(context, fn ->
#       with :ok <- Events.initialize(),
#            :ok <- Telemetry.initialize() do
#         :ok
#       end
#     end)
#   end
# end
