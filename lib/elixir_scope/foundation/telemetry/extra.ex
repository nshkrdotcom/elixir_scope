# # ORIG_FILE
# defmodule ElixirScope.Foundation.Telemetry do
#   @moduledoc """
#   Telemetry and metrics collection for ElixirScope Foundation layer.

#   Provides standardized telemetry events and metrics collection
#   for monitoring ElixirScope performance and health.
#   """

#   require Logger
#   alias ElixirScope.Foundation.Utils

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

#   @spec measure_event(list(atom()), map(), (() -> t)) :: t when t: var
#   def measure_event(event_name, metadata \\ %{}, fun) do
#     start_time = Utils.monotonic_timestamp()

#     result = try do
#       fun.()
#     rescue
#       error ->
#         emit_error_event(event_name, metadata, error)
#         reraise error, __STACKTRACE__
#     end

#     end_time = Utils.monotonic_timestamp()
#     duration = end_time - start_time

#     measurements = %{duration: duration, timestamp: end_time}
#     :telemetry.execute(event_name, measurements, metadata)

#     result
#   end

#   @spec emit_counter(list(atom()), map()) :: :ok
#   def emit_counter(event_name, metadata \\ %{}) do
#     measurements = %{count: 1, timestamp: Utils.monotonic_timestamp()}
#     :telemetry.execute(event_name, measurements, metadata)
#   end

#   @spec emit_gauge(list(atom()), number(), map()) :: :ok
#   def emit_gauge(event_name, value, metadata \\ %{}) do
#     measurements = %{value: value, timestamp: Utils.monotonic_timestamp()}
#     :telemetry.execute(event_name, measurements, metadata)
#   end

#   @spec get_metrics() :: map()
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

#   defp attach_default_handlers do
#     # Attach a default handler for debugging in development
#     if Application.get_env(:elixir_scope, :dev, %{}) |> Map.get(:debug_mode, false) do
#       :telemetry.attach_many(
#         "elixir-scope-debug-handler",
#         @telemetry_events,
#         &handle_debug_event/4,
#         %{}
#       )
#     end
#   end

#   defp handle_debug_event(event_name, measurements, metadata, _config) do
#     Logger.debug("""
#     ElixirScope Telemetry Event:
#       Event: #{inspect(event_name)}
#       Measurements: #{inspect(measurements)}
#       Metadata: #{inspect(metadata)}
#     """)
#   end

#   defp emit_error_event(event_name, metadata, error) do
#     error_metadata = Map.merge(metadata, %{
#       error_type: error.__struct__,
#       error_message: Exception.message(error)
#     })

#     measurements = %{error_count: 1, timestamp: Utils.monotonic_timestamp()}
#     error_event_name = event_name ++ [:error]
#     :telemetry.execute(error_event_name, measurements, error_metadata)
#   end
# end
