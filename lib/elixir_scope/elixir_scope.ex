defmodule ElixirScope do
  @moduledoc """
  ElixirScope - Revolutionary AST-based debugging and code intelligence platform.

  ElixirScope is the main entry point for the system. It provides a unified
  interface for accessing all ElixirScope functionality.
  """

  alias ElixirScope.Foundation
  alias ElixirScope.Foundation.{Error, ErrorContext}

  @doc """
  Initialize ElixirScope with optional configuration.
  """
  @spec initialize(keyword()) :: :ok | {:error, Error.t()}
  def initialize(opts \\ []) do
    Foundation.initialize(opts)
  end

  @doc """
  Get the current status of all ElixirScope subsystems.
  """
  @spec status() :: %{
          config: :ok | {:error, Error.t()},
          events: :ok | {:error, Error.t()},
          telemetry: :ok | {:error, Error.t()},
          uptime_ms: non_neg_integer()
        }
  def status do
    Foundation.status()
  end

  @doc """
  Start ElixirScope (alias for initialize/1).
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, Error.t()}
  def start_link(opts \\ []) do
    context = ErrorContext.new(__MODULE__, :start_link, metadata: %{opts: opts})

    ErrorContext.with_context(context, fn ->
      case initialize(opts) do
        :ok -> {:ok, self()}
        {:error, _} = error -> error
      end
    end)
  end
end

# defmodule ElixirScope do
#   @moduledoc """
#   ElixirScope - AI-Powered Execution Cinema Debugger

#   ElixirScope provides deep observability and "execution cinema" capabilities
#   for Elixir applications. It enables time-travel debugging, comprehensive
#   event capture, and AI-powered analysis of concurrent systems.

#   ## Features

#   - **Total Recall**: Capture complete execution history with minimal overhead
#   - **AI-Driven Instrumentation**: Intelligent, automatic code instrumentation
#   - **Execution Cinema**: Visual time-travel debugging interface
#   - **Multi-Dimensional Analysis**: Correlate events across time, processes, state, and causality
#   - **Performance Aware**: <1% overhead in production with smart sampling

#   ## Architectural Responsibilities

#   The `ElixirScope` module serves as the primary public interface for the entire ElixirScope system. Its core responsibilities include:
#   - **Application Lifecycle Management**: Provides functions to start and stop the ElixirScope application, ensuring proper initialization and shutdown of all underlying components.
#   - **Public API Exposure**: Exposes a high-level API for users to interact with the debugger, including querying captured events, retrieving state history, analyzing code, and updating instrumentation.
#   - **Orchestration and Coordination**: Delegates complex operations to specialized modules within the `Foundation` layer, acting as a coordinator for various system functionalities (e.g., AI management, event management, state tracking).
#   - **Configuration Management**: Allows for runtime configuration updates and retrieval of the current system configuration.

#   ## Dependencies

#   This module depends on the following key components:
#   - `ElixirScope.Application`: Manages the OTP application lifecycle.
#   - `ElixirScope.Config`: Provides access to and management of system configuration.
#   - `ElixirScope.Foundation.*`: Relies heavily on modules within the `Foundation` layer (e.g., `EventManager`, `StateManager`, `MessageTracker`, `AIManager`, `Utils`) to perform core operations and data retrieval.
#   - `ElixirScope.Supervisor`: Used to verify the running status of the main application supervisor.
#   - `Logger`: For internal logging and status reporting.

#   ## Quick Start

#       # Start ElixirScope with default configuration
#       ElixirScope.start()

#       # Configure for development with full tracing
#       ElixirScope.start(strategy: :full_trace)

#       # Query captured events
#       events = ElixirScope.get_events(pid: self(), limit: 100)

#       # Stop tracing
#       ElixirScope.stop()

#   ## Configuration

#   ElixirScope can be configured via `config.exs`:

#       config :elixir_scope,
#         ai: [
#           planning: [
#             default_strategy: :balanced,
#             performance_target: 0.01,
#             sampling_rate: 1.0
#           ]
#         ],
#         capture: [
#           ring_buffer: [
#             size: 1_048_576,
#             max_events: 100_000
#           ]
#         ]

#   See `ElixirScope.Config` for all available configuration options.
#   """

#   require Logger

#   @type start_option ::
#     {:strategy, :minimal | :balanced | :full_trace} |
#     {:sampling_rate, float()} |
#     {:modules, [module()]} |
#     {:exclude_modules, [module()]}

#   @type event_query :: [
#     pid: pid() | :all,
#     event_type: atom() | :all,
#     since: integer() | DateTime.t(),
#     until: integer() | DateTime.t(),
#     limit: pos_integer()
#   ]

#   #############################################################################
#   # Public API
#   #############################################################################

#   @doc """
#   Starts ElixirScope with the given options.

#   ## Options

#   - `:strategy` - Instrumentation strategy (`:minimal`, `:balanced`, `:full_trace`)
#   - `:sampling_rate` - Event sampling rate (0.0 to 1.0)
#   - `:modules` - Specific modules to instrument (overrides AI planning)
#   - `:exclude_modules` - Modules to exclude from instrumentation

#   ## Examples

#       # Start with default configuration
#       ElixirScope.start()

#       # Start with full tracing for debugging
#       ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)

#       # Start with minimal overhead for production
#       ElixirScope.start(strategy: :minimal, sampling_rate: 0.1)

#       # Instrument only specific modules
#       ElixirScope.start(modules: [MyApp.Worker, MyApp.Server])
#   """
#   @spec start([start_option()]) :: :ok | {:error, Error.t()}
#   def start(opts \\ []) do
#     case Application.ensure_all_started(:elixir_scope) do
#       {:ok, _} ->
#         configure_runtime_options(opts)
#         Logger.info("ElixirScope started successfully")
#         :ok

#       {:error, reason} ->
#         Logger.error("Failed to start ElixirScope: #{inspect(reason)}")
#         {:error, reason}
#     end
#   end

#   @doc """
#   Stops ElixirScope and all tracing.

#   ## Examples

#       ElixirScope.stop()
#   """
#   @spec stop() :: :ok
#   def stop do
#     case Application.stop(:elixir_scope) do
#       :ok ->
#         Logger.info("ElixirScope stopped")
#         :ok

#       {:error, reason} ->
#         Logger.warning("Error stopping ElixirScope: #{inspect(reason)}")
#         :ok  # Don't fail, just log the warning
#     end
#   end

#   @doc """
#   Gets the current status of ElixirScope.

#   Returns a map with information about:
#   - Whether ElixirScope is running
#   - Current configuration
#   - Performance statistics
#   - Storage usage

#   ## Examples

#       status = ElixirScope.status()
#       # %{
#       #   running: true,
#       #   config: %{...},
#       #   stats: %{events_captured: 12345, ...},
#       #   storage: %{hot_events: 5000, memory_usage: "2.1 MB"}
#       # }
#   """
#   @spec status() :: map()
#   def status do
#     is_running = running?()
#     base_status = %{
#       running: is_running,
#       timestamp: ElixirScope.Foundation.Utils.wall_timestamp()
#     }

#     if is_running do
#       base_status
#       |> Map.put(:config, get_current_config())
#       |> Map.put(:stats, get_performance_stats())
#       |> Map.put(:storage, get_storage_stats())
#     else
#       base_status
#     end
#   end

#   @doc """
#   Queries captured events based on the given criteria.

#   ## Query Options

#   - `:pid` - Filter by process ID (`:all` for all processes)
#   - `:event_type` - Filter by event type (`:all` for all types)
#   - `:since` - Events since timestamp or DateTime
#   - `:until` - Events until timestamp or DateTime
#   - `:limit` - Maximum number of events to return

#   ## Examples

#       # Get last 100 events for current process
#       events = ElixirScope.get_events(pid: self(), limit: 100)

#       # Get all function entry events
#       events = ElixirScope.get_events(event_type: :function_entry)

#       # Get events from the last minute
#       since = DateTime.utc_now() |> DateTime.add(-60, :second)
#       events = ElixirScope.get_events(since: since)
#   """
#   @spec get_events(event_query()) :: [ElixirScope.Events.t()] | {:error, Error.t()}
#   def get_events(query \\ []) do
#     if running?() do
#       case ElixirScope.Foundation.EventManager.get_events(query) do
#         {:ok, events} -> events
#         {:error, reason} -> {:error, reason}
#       end
#     else
#       {:error, :not_running}
#     end
#   end

#   @doc """
#   Gets the state history for a GenServer process.

#   Returns a chronological list of state changes for the given process.

#   ## Examples

#       # Get state history for a GenServer
#       history = ElixirScope.get_state_history(pid)

#       # Get state at a specific time
#       state = ElixirScope.get_state_at(pid, timestamp)
#   """
#   @spec get_state_history(pid()) :: [ElixirScope.Events.StateChange.t()] | {:error, Error.t()}
#   def get_state_history(pid) when is_pid(pid) do
#     if running?() do
#       case ElixirScope.Foundation.StateManager.get_state_history(pid) do
#         {:ok, history} -> history
#         {:error, reason} -> {:error, reason}
#       end
#     else
#       {:error, :not_running}
#     end
#   end

#   @doc """
#   Reconstructs the state of a GenServer at a specific timestamp.

#   ## Examples

#       timestamp = ElixirScope.Foundation.Utils.monotonic_timestamp()
#       state = ElixirScope.get_state_at(pid, timestamp)
#   """
#   @spec get_state_at(pid(), integer()) :: Error.t() | {:error, Error.t()}
#   def get_state_at(pid, timestamp) when is_pid(pid) and is_integer(timestamp) do
#     if running?() do
#       case ElixirScope.Foundation.StateManager.get_state_at(pid, timestamp) do
#         {:ok, state} -> state
#         {:error, reason} -> {:error, reason}
#       end
#     else
#       {:error, :not_running}
#     end
#   end

#   @doc """
#   Gets message flow between two processes.

#   Returns all messages sent between the specified processes within
#   the given time range.

#   ## Examples

#       # Get all messages between two processes
#       messages = ElixirScope.get_message_flow(sender_pid, receiver_pid)

#       # Get messages in a time range
#       messages = ElixirScope.get_message_flow(
#         sender_pid,
#         receiver_pid,
#         since: start_time,
#         until: end_time
#       )
#   """
#   @spec get_message_flow(pid(), pid(), keyword()) :: [ElixirScope.Events.MessageSend.t()] | {:error, Error.t()}
#   def get_message_flow(sender_pid, receiver_pid, opts \\ [])
#       when is_pid(sender_pid) and is_pid(receiver_pid) do
#     if running?() do
#       case ElixirScope.Foundation.MessageTracker.get_message_flow(sender_pid, receiver_pid, opts) do
#         {:ok, flow} -> flow
#         {:error, reason} -> {:error, reason}
#       end
#     else
#       {:error, :not_running}
#     end
#   end

#   @doc """
#   Manually triggers AI analysis of the current codebase.

#   This can be useful to refresh instrumentation plans after code changes
#   or to analyze new modules.

#   ## Examples

#       # Analyze entire codebase
#       ElixirScope.analyze_codebase()

#       # Analyze specific modules
#       ElixirScope.analyze_codebase(modules: [MyApp.NewModule])
#   """
#   @spec analyze_codebase(keyword()) :: :ok | {:error, Error.t()}
#   def analyze_codebase(opts \\ []) do
#     if running?() do
#       case ElixirScope.Foundation.AIManager.analyze_codebase(opts) do
#         {:ok, analysis} -> analysis
#         {:error, reason} -> {:error, reason}
#       end
#     else
#       {:error, :not_running}
#     end
#   end

#   @doc """
#   Updates the instrumentation plan at runtime.

#   This allows changing which modules and functions are being traced
#   without restarting the application.

#   ## Examples

#       # Change sampling rate
#       ElixirScope.update_instrumentation(sampling_rate: 0.5)

#       # Add modules to trace
#       ElixirScope.update_instrumentation(add_modules: [MyApp.NewModule])

#       # Change strategy
#       ElixirScope.update_instrumentation(strategy: :full_trace)
#   """
#   @spec update_instrumentation(keyword()) :: :ok | {:error, Error.t()}
#   def update_instrumentation(updates) do
#     if running?() do
#       case ElixirScope.Foundation.AIManager.update_instrumentation(updates) do
#         {:ok, result} -> result
#         {:error, reason} -> {:error, reason}
#       end
#     else
#       {:error, :not_running}
#     end
#   end

#   #############################################################################
#   # Convenience Functions
#   #############################################################################

#   @doc """
#   Checks if ElixirScope is currently running.

#   ## Examples

#       if ElixirScope.running?() do
#         # ElixirScope is active
#       end
#   """
#   @spec running?() :: boolean()
#   def running? do
#     # Check if the application is started by checking both the Application and the supervisor
#     case Application.get_application(__MODULE__) do
#       nil -> false
#       :elixir_scope ->
#         # Also check if the main supervisor is running
#         case Process.whereis(ElixirScope.Supervisor) do
#           nil -> false
#           _pid -> true
#         end
#     end
#   end

#   @doc """
#   Gets the current configuration.

#   ## Examples

#       config = ElixirScope.get_config()
#       sampling_rate = config.ai.planning.sampling_rate
#   """
#   @spec get_config() :: ElixirScope.Config.t() | {:error, Error.t()}
#   def get_config do
#     if running?() do
#       ElixirScope.Config.get()
#     else
#       {:error, :not_running}
#     end
#   end

#   @doc """
#   Updates configuration at runtime.

#   Only certain configuration paths can be updated at runtime for safety.

#   ## Examples

#       # Update sampling rate
#       ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.8)

#       # Update query timeout
#       ElixirScope.update_config([:interface, :query_timeout], 10_000)
#   """
#   @spec update_config([atom()], Error.t()) :: :ok | {:error, Error.t()}
#   def update_config(path, value) do
#     if running?() do
#       ElixirScope.Config.update(path, value)
#     else
#       {:error, :not_running}
#     end
#   end

#   #############################################################################
#   # Private Functions
#   #############################################################################

#   defp configure_runtime_options(opts) do
#     # Apply runtime configuration options
#     Enum.each(opts, fn {key, value} ->
#       case key do
#         :strategy ->
#           update_config([:ai, :planning, :default_strategy], value)

#         :sampling_rate ->
#           update_config([:ai, :planning, :sampling_rate], value)

#         :modules ->
#           # TODO: Set specific modules to instrument
#           Logger.info("Module-specific instrumentation will be available in Layer 4")

#         :exclude_modules ->
#           # TODO: Add to exclusion list
#           Logger.info("Module exclusion configuration will be available in Layer 4")

#         _ ->
#           Logger.warning("Unknown start option: #{key}")
#       end
#     end)
#   end

#   defp get_current_config do
#     case get_config() do
#       {:error, _} -> %{}
#       config ->
#         # Return a simplified view of the configuration
#         %{
#           strategy: config.ai.planning.default_strategy,
#           sampling_rate: config.ai.planning.sampling_rate,
#           performance_target: config.ai.planning.performance_target,
#           ring_buffer_size: config.capture.ring_buffer.size,
#           hot_storage_limit: config.storage.hot.max_events
#         }
#     end
#   end

#   defp get_performance_stats do
#     # TODO: Implement in Layer 1 when capture pipeline is available
#     %{
#       events_captured: 0,
#       events_per_second: 0,
#       memory_usage: 0,
#       ring_buffer_utilization: 0.0,
#       last_updated: ElixirScope.Foundation.Utils.wall_timestamp()
#     }
#   end

#   defp get_storage_stats do
#     # TODO: Implement in Layer 2 when storage is available
#     %{
#       hot_events: 0,
#       warm_events: 0,
#       cold_events: 0,
#       memory_usage: ElixirScope.Foundation.Utils.format_bytes(0),
#       disk_usage: ElixirScope.Foundation.Utils.format_bytes(0),
#       oldest_event: nil,
#       newest_event: nil
#     }
#   end
# end
