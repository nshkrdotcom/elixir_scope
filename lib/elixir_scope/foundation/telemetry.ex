defmodule ElixirScope.Foundation.Telemetry do
  @moduledoc """
  Public API for telemetry and metrics collection.

  Thin wrapper around TelemetryService that provides a clean, documented interface.
  All business logic is delegated to the service layer.
  """

  alias ElixirScope.Foundation.Services.TelemetryService
  alias ElixirScope.Foundation.Types.Error

  @type event_name :: [atom()]
  @type measurements :: map()
  @type metadata :: map()
  @type metric_value :: number()

  @doc """
  Initialize the telemetry service.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.initialize()
      :ok
  """
  @spec initialize() :: :ok | {:error, Error.t()}
  def initialize() do
    TelemetryService.initialize()
  end

  @doc """
  Get telemetry service status.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.status()
      {:ok, %{status: :running, uptime: 12345}}
  """
  @spec status() :: {:ok, map()} | {:error, Error.t()}
  def status() do
    TelemetryService.status()
  end

  @doc """
  Execute telemetry event with measurements.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.execute(
      ...>   [:elixir_scope, :function, :call],
      ...>   %{duration: 1000},
      ...>   %{module: MyModule, function: :my_func}
      ...> )
      :ok
  """
  @spec execute(event_name(), measurements(), metadata()) :: :ok
  defdelegate execute(event_name, measurements, metadata), to: TelemetryService

  @doc """
  Measure execution time and emit results.

  ## Examples

      iex> result = ElixirScope.Foundation.Telemetry.measure(
      ...>   [:elixir_scope, :query, :execution],
      ...>   %{query_type: :complex},
      ...>   fn -> expensive_operation() end
      ...> )
      :operation_result
  """
  @spec measure(event_name(), metadata(), (() -> result)) :: result when result: var
  defdelegate measure(event_name, metadata, fun), to: TelemetryService

  @doc """
  Emit a counter metric.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.emit_counter(
      ...>   [:elixir_scope, :events, :processed],
      ...>   %{event_type: :function_entry}
      ...> )
      :ok
  """
  @spec emit_counter(event_name(), metadata()) :: :ok
  defdelegate emit_counter(event_name, metadata), to: TelemetryService

  @doc """
  Emit a gauge metric.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.emit_gauge(
      ...>   [:elixir_scope, :memory, :usage],
      ...>   1024000,
      ...>   %{unit: :bytes}
      ...> )
      :ok
  """
  @spec emit_gauge(event_name(), metric_value(), metadata()) :: :ok
  defdelegate emit_gauge(event_name, value, metadata), to: TelemetryService

  @doc """
  Get collected metrics.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.get_metrics()
      {:ok, %{
        [:elixir_scope, :function, :call] => %{
          timestamp: 123456789,
          measurements: %{duration: 1500},
          count: 42
        }
      }}
  """
  @spec get_metrics() :: {:ok, map()} | {:error, Error.t()}
  defdelegate get_metrics(), to: TelemetryService

  @doc """
  Attach event handlers for specific events.

  ## Examples

      iex> events = [[:elixir_scope, :function, :call], [:elixir_scope, :query, :execution]]
      iex> ElixirScope.Foundation.Telemetry.attach_handlers(events)
      :ok
  """
  @spec attach_handlers([event_name()]) :: :ok | {:error, Error.t()}
  defdelegate attach_handlers(event_names), to: TelemetryService

  @doc """
  Detach event handlers.

  ## Examples

      iex> events = [[:elixir_scope, :function, :call]]
      iex> ElixirScope.Foundation.Telemetry.detach_handlers(events)
      :ok
  """
  @spec detach_handlers([event_name()]) :: :ok
  defdelegate detach_handlers(event_names), to: TelemetryService

  @doc """
  Check if telemetry is available.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.available?()
      true
  """
  @spec available?() :: boolean()
  defdelegate available?(), to: TelemetryService

  @doc """
  Time a function execution and emit telemetry.

  Convenience function that automatically creates appropriate event names.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.time_function(
      ...>   MyModule, :expensive_function,
      ...>   fn -> MyModule.expensive_function(arg1, arg2) end
      ...> )
      :function_result
  """
  @spec time_function(module(), atom(), (() -> result)) :: result when result: var
  def time_function(module, function, fun) when is_atom(module) and is_atom(function) do
    event_name = [:elixir_scope, :function, :execution]
    metadata = %{module: module, function: function}
    measure(event_name, metadata, fun)
  end

  @doc """
  Emit a performance metric with automatic categorization.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.emit_performance(
      ...>   :query_duration, 1500, %{query_type: :complex}
      ...> )
      :ok
  """
  @spec emit_performance(atom(), metric_value(), metadata()) :: :ok
  def emit_performance(metric_name, value, metadata \\ %{}) when is_atom(metric_name) do
    event_name = [:elixir_scope, :performance, metric_name]
    emit_gauge(event_name, value, metadata)
  end

  @doc """
  Emit a system event counter.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.emit_system_event(:error, %{error_type: :validation})
      :ok
  """
  @spec emit_system_event(atom(), metadata()) :: :ok
  def emit_system_event(event_type, metadata \\ %{}) when is_atom(event_type) do
    event_name = [:elixir_scope, :system, event_type]
    emit_counter(event_name, metadata)
  end

  @doc """
  Get metrics for a specific event pattern.

  ## Examples

      iex> ElixirScope.Foundation.Telemetry.get_metrics_for([:elixir_scope, :function])
      {:ok, %{...}}  # Only metrics matching the pattern
  """
  @spec get_metrics_for(event_name()) :: {:ok, map()} | {:error, Error.t()}
  def get_metrics_for(event_pattern) when is_list(event_pattern) do
    case get_metrics() do
      {:ok, all_metrics} ->
        filtered_metrics =
          all_metrics
          |> Enum.filter(fn {event_name, _} ->
            List.starts_with?(event_name, event_pattern)
          end)
          |> Map.new()

        {:ok, filtered_metrics}

      {:error, _} = error ->
        error
    end
  end
end

# defmodule ElixirScope.Foundation.Telemetry do
#   @moduledoc """
#   Telemetry and metrics collection for ElixirScope Foundation layer.

#   Provides standardized telemetry events and metrics collection
#   for monitoring ElixirScope performance and health.
#   """

#   require Logger
#   # , Error} #, ErrorContext}
#   alias ElixirScope.Foundation.{Utils}

#   @telemetry_events [
#     # Configuration events
#     [:elixir_scope, :config, :get],
#     [:elixir_scope, :config, :update],
#     [:elixir_scope, :config, :validate],

#     # Event system events
#     [:elixir_scope, :events, :create],
#     [:elixir_scope, :events, :serialize],
#     [:elixir_scope, :events, :deserialize],

#     # Performance events
#     [:elixir_scope, :performance, :measurement],
#     [:elixir_scope, :performance, :memory_usage]
#   ]

#   ## Public API

#   @spec initialize() :: :ok
#   def initialize do
#     attach_default_handlers()
#     Logger.debug("ElixirScope.Foundation.Telemetry initialized")
#     :ok
#   end

#   @spec status() :: :ok
#   def status, do: :ok

#   @spec measure_event([atom(), ...], map(), (-> t)) :: t when t: var
#   def measure_event(event_name, metadata \\ %{}, fun) when is_function(fun, 0) do
#     start_time = Utils.monotonic_timestamp()

#     # Don't wrap in ErrorContext - let exceptions propagate
#     try do
#       result = fun.()

#       end_time = Utils.monotonic_timestamp()
#       duration = end_time - start_time

#       measurements = %{duration: duration, timestamp: end_time}
#       :telemetry.execute(event_name, measurements, metadata)

#       result
#     rescue
#       exception ->
#         # Still measure the duration even if it failed
#         end_time = Utils.monotonic_timestamp()
#         duration = end_time - start_time

#         measurements = %{duration: duration, timestamp: end_time}
#         error_metadata = Map.put(metadata, :exception, exception)

#         # Emit both the normal event and an error event
#         :telemetry.execute(event_name, measurements, error_metadata)
#         emit_error_event(event_name, metadata, {:error, exception})

#         # Re-raise the exception so the test can catch it
#         reraise exception, __STACKTRACE__
#     end
#   end

#   @spec emit_counter([atom(), ...], map()) :: :ok
#   def emit_counter(event_name, metadata \\ %{}) do
#     measurements = %{count: 1, timestamp: Utils.monotonic_timestamp()}
#     :telemetry.execute(event_name, measurements, metadata)
#   end

#   @spec emit_gauge(list(atom()), number(), map()) :: :ok
#   def emit_gauge(event_name, value, metadata \\ %{}) do
#     measurements = %{value: value, timestamp: Utils.monotonic_timestamp()}
#     :telemetry.execute(event_name, measurements, metadata)
#   end

#   @spec get_metrics() :: %{
#           foundation: %{
#             uptime_ms: integer(),
#             memory_usage: non_neg_integer(),
#             process_count: non_neg_integer()
#           },
#           system: %{
#             timestamp: integer(),
#             process_count: non_neg_integer(),
#             total_memory: non_neg_integer(),
#             scheduler_count: pos_integer(),
#             otp_release: binary()
#           }
#         }
#   def get_metrics do
#     %{
#       foundation: %{
#         uptime_ms: System.monotonic_time(:millisecond),
#         memory_usage: :erlang.memory(:total),
#         process_count: :erlang.system_info(:process_count)
#       },
#       system: Utils.system_stats()
#     }
#   end

#   ## Private Functions

#   @spec attach_default_handlers() :: :ok
#   defp attach_default_handlers do
#     # Attach a default handler for debugging in development
#     if Application.get_env(:elixir_scope, :dev, []) |> Keyword.get(:debug_mode, false) do
#       :telemetry.attach_many(
#         "elixir-scope-debug-handler",
#         @telemetry_events,
#         &handle_debug_event/4,
#         %{}
#       )
#     end

#     :ok
#   end

#   @spec handle_debug_event(list(atom()), map(), map(), map()) :: :ok
#   defp handle_debug_event(event_name, measurements, metadata, _config) do
#     Logger.debug("""
#     ElixirScope Telemetry Event:
#       Event: #{inspect(event_name)}
#       Measurements: #{inspect(measurements)}
#       Metadata: #{inspect(metadata)}
#     """)
#   end

#   @spec emit_error_event([atom(), ...], map(), {:error, struct()}) :: :ok
#   defp emit_error_event(event_name, metadata, {:error, err}) do
#     error_metadata =
#       if err.__struct__ == ElixirScope.Foundation.Error do
#         Map.merge(metadata, %{
#           error_code: err.code,
#           error_message: err.message
#         })
#       else
#         Map.merge(metadata, %{
#           error_type: :external_error,
#           error_message: inspect(err)
#         })
#       end

#     measurements = %{error_count: 1, timestamp: Utils.monotonic_timestamp()}
#     error_event_name = event_name ++ [:error]
#     :telemetry.execute(error_event_name, measurements, error_metadata)
#   end
# end
