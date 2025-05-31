# defmodule ElixirScope.Foundation.Utils do
#   @moduledoc """
#   Core utility functions for ElixirScope Foundation layer.

#   Provides essential utilities for ID generation, time measurement,
#   data inspection, and performance monitoring.
#   """

#   import Bitwise
#   alias ElixirScope.Foundation.Types

#   @type measurement_result(t) :: {t, non_neg_integer()}

#   #############################################################################
#   # Timestamp Generation
#   #############################################################################

#   @doc """
#   Generates a high-resolution monotonic timestamp in nanoseconds.

#   This timestamp is guaranteed to be monotonically increasing and is suitable
#   for ordering events and measuring durations. It's not affected by system
#   clock adjustments.

#   ## Examples

#       iex> ElixirScope.Utils.monotonic_timestamp()
#       315708474309417000
#   """
#   @spec monotonic_timestamp() :: Types.timestamp()
#   def monotonic_timestamp do
#     System.monotonic_time(:nanosecond)
#   end

#   @doc """
#   Generates a wall clock timestamp in nanoseconds.

#   This timestamp represents the actual time and can be converted to
#   human-readable dates. Use for correlation with external systems.

#   ## Examples

#       iex> ElixirScope.Utils.wall_timestamp()
#       1609459200000000000
#   """
#   @spec wall_timestamp() :: Types.timestamp()
#   def wall_timestamp do
#     System.os_time(:nanosecond)
#   end

#   @doc """
#   Converts a monotonic timestamp to a human-readable string.

#   ## Examples

#       iex> ElixirScope.Utils.format_timestamp(315708474309417000)
#       "2024-01-01 12:30:45.123456789"
#   """
#   @spec format_timestamp(Types.timestamp()) :: String.t()
#   def format_timestamp(timestamp_ns) when is_integer(timestamp_ns) do
#     timestamp_us = div(timestamp_ns, 1_000)
#     datetime = DateTime.from_unix!(timestamp_us, :microsecond)

#     # Format with nanosecond precision
#     nanoseconds = rem(timestamp_ns, 1_000_000)
#     formatted_base = DateTime.to_iso8601(datetime)

#     # Replace microseconds with full nanosecond precision
#     String.replace(formatted_base, ~r/\.\d{6}/, ".#{:io_lib.format("~6..0B", [nanoseconds])}")
#   end

#   @doc """
#   Measures execution time of a function in nanoseconds.

#   ## Examples

#       iex> {result, duration} = ElixirScope.Utils.measure(fn -> :timer.sleep(10); :ok end)
#       iex> result
#       :ok
#       iex> duration > 10_000_000  # At least 10ms in nanoseconds
#       true
#   """
#   @spec measure((() -> t)) :: measurement_result(t) when t: var
#   def measure(fun) when is_function(fun, 0) do
#     start_time = monotonic_timestamp()
#     result = fun.()
#     end_time = monotonic_timestamp()

#     {result, end_time - start_time}
#   end

#   #############################################################################
#   # ID Generation
#   #############################################################################

#   @doc """
#   Generates a unique ID for events, calls, and other entities.

#   The ID is designed to be:
#   - Globally unique across nodes and time
#   - Sortable (roughly by creation time)
#   - Compact for storage efficiency
#   - Fast to generate

#   ## Examples

#       iex> id1 = ElixirScope.Utils.generate_id()
#       iex> id2 = ElixirScope.Utils.generate_id()
#       iex> id1 != id2
#       true
#   """
#   @spec generate_id() :: Types.event_id()
#   def generate_id do
#     # Use a combination of timestamp and random value for uniqueness
#     timestamp = System.monotonic_time(:nanosecond)
#     random = :rand.uniform(1_000_000)

#     # Combine timestamp and random for globally unique ID
#     # Use abs to handle negative monotonic time
#     abs(timestamp) * 1_000_000 + random
#   end

#   @doc """
#   Generates a unique correlation ID for tracing events.
#   Returns a UUID v4 string for compatibility with external systems.
#   """
#   @spec generate_correlation_id() :: Types.correlation_id()
#   def generate_correlation_id do
#     # Generate UUID v4 format
#     <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)

#     # Set version (4) and variant bits
#     u2_v4 = u2 &&& 0x0FFF ||| 0x4000
#     u3_var = u3 &&& 0x3FFF ||| 0x8000

#     :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
#                    [u0, u1, u2_v4, u3_var, u4])
#     |> IO.iodata_to_binary()
#   end

#   @doc """
#   Extracts the timestamp component from a generated ID.

#   ## Examples

#       iex> id = ElixirScope.Utils.generate_id()
#       iex> timestamp = ElixirScope.Utils.id_to_timestamp(id)
#       iex> is_integer(timestamp)
#       true
#   """
#   @spec id_to_timestamp(Types.event_id()) :: Types.timestamp()
#   def id_to_timestamp(id) when is_integer(id) do
#     # Extract timestamp component from ID
#     div(id, 1_000_000)
#   end

#   #############################################################################
#   # Data Inspection and Truncation
#   #############################################################################

#   @doc """
#   Safely inspects a term with size limits to prevent memory issues.

#   ## Examples

#       iex> ElixirScope.Utils.safe_inspect(%{key: "value"})
#       "%{key: \"value\"}"

#       iex> large_map = for i <- 1..1000, into: %{}, do: {i, i}
#       iex> result = ElixirScope.Utils.safe_inspect(large_map)
#       iex> String.contains?(result, "...")
#       true
#   """
#   @spec safe_inspect(term(), keyword()) :: String.t()
#   def safe_inspect(term, opts \\ []) do
#     limit = Keyword.get(opts, :limit, 50)

#     inspect(term, limit: limit, printable_limit: 100, pretty: true)
#   end

#   @doc """
#   Truncates a term if it's too large, returning a placeholder.

#   ## Examples

#       iex> ElixirScope.Utils.truncate_if_large("small")
#       "small"

#       iex> large_binary = String.duplicate("x", 10000)
#       iex> ElixirScope.Utils.truncate_if_large(large_binary, 1000)
#       {:truncated, 10000, "binary data"}
#   """
#   @spec truncate_if_large(term(), non_neg_integer()) :: term() | {:truncated, non_neg_integer(), String.t()}
#   def truncate_if_large(term, size_limit \\ 1000) do
#     estimated_size = term_size(term)

#     if estimated_size <= size_limit do
#       term
#     else
#       type_hint = get_type_hint(term)
#       {:truncated, estimated_size, type_hint}
#     end
#   end

#   @doc """
#   Estimates the memory footprint of a term in bytes.

#   ## Examples

#       iex> ElixirScope.Utils.term_size("hello")
#       15
#   """
#   @spec term_size(term()) :: non_neg_integer()
#   def term_size(term) do
#     :erlang.external_size(term)
#   end

#   @doc """
#   Truncates data for safe storage in events.

#   This is an alias for truncate_if_large/2 with a smaller default size
#   suitable for event data.

#   ## Examples

#       iex> ElixirScope.Utils.truncate_data("small")
#       "small"

#       iex> large_data = String.duplicate("x", 2000)
#       iex> ElixirScope.Utils.truncate_data(large_data)
#       {:truncated, 2000, "binary data"}
#   """
#   def truncate_data(term, max_size \\ 1000) do
#     truncate_if_large(term, max_size)
#   end

#   #############################################################################
#   # Performance Helpers
#   #############################################################################

#   @doc """
#   Measures memory usage before and after executing a function.

#   Returns {result, {memory_before, memory_after, memory_diff}}.

#   ## Examples

#       iex> {result, {before, after, diff}} = ElixirScope.Utils.measure_memory(fn ->
#       ...>   Enum.to_list(1..1000)
#       ...> end)
#       iex> is_list(result)
#       true
#       iex> diff > 0
#       true
#   """
#   @spec measure_memory((() -> t)) :: {t, {non_neg_integer(), non_neg_integer(), integer()}} when t: var
#   def measure_memory(fun) when is_function(fun, 0) do
#     memory_before = :erlang.memory(:total)
#     result = fun.()
#     memory_after = :erlang.memory(:total)

#     {result, {memory_before, memory_after, memory_after - memory_before}}
#   end

#   @doc """
#   Gets current process statistics for performance monitoring.

#   ## Examples

#       iex> stats = ElixirScope.Utils.process_stats()
#       iex> Map.has_key?(stats, :memory)
#       true
#       iex> Map.has_key?(stats, :reductions)
#       true
#   """
#   @spec process_stats(pid()) :: map()
#   def process_stats(pid \\ self()) do
#     case Process.info(pid, [:memory, :reductions, :message_queue_len]) do
#       nil ->
#         %{error: :process_not_found, timestamp: monotonic_timestamp()}

#       info ->
#         info
#         |> Keyword.put(:timestamp, monotonic_timestamp())
#         |> Enum.into(%{})
#     end
#   end

#   @doc """
#   Gets system-wide performance statistics.

#   ## Examples

#       iex> stats = ElixirScope.Utils.system_stats()
#       iex> Map.has_key?(stats, :process_count)
#       true
#       iex> Map.has_key?(stats, :total_memory)
#       true
#   """
#   @spec system_stats() :: map()
#   def system_stats do
#     %{
#       timestamp: monotonic_timestamp(),
#       process_count: :erlang.system_info(:process_count),
#       total_memory: :erlang.memory(:total),
#       scheduler_count: :erlang.system_info(:schedulers),
#       otp_release: :erlang.system_info(:otp_release) |> List.to_string()
#     }
#   end

#   #############################################################################
#   # String and Data Utilities
#   #############################################################################

#   @doc """
#   Formats a byte size into a human-readable string.

#   ## Examples

#       iex> ElixirScope.Utils.format_bytes(1024)
#       "1.0 KB"

#       iex> ElixirScope.Utils.format_bytes(1_500_000)
#       "1.4 MB"
#   """
#   @spec format_bytes(non_neg_integer()) :: String.t()
#   def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
#     cond do
#       bytes < 1024 -> "#{bytes} B"
#       bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
#       bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
#       true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
#     end
#   end

#   @doc """
#   Formats a duration in nanoseconds into a human-readable string.

#   ## Examples

#       iex> ElixirScope.Utils.format_duration(1_500_000)
#       "1.5 ms"

#       iex> ElixirScope.Utils.format_duration(2_000_000_000)
#       "2.0 s"
#   """
#   @spec format_duration(non_neg_integer()) :: String.t()
#   def format_duration(nanoseconds) when is_integer(nanoseconds) and nanoseconds >= 0 do
#     cond do
#       nanoseconds < 1_000 -> "#{nanoseconds} ns"
#       nanoseconds < 1_000_000 -> "#{Float.round(nanoseconds / 1_000, 1)} μs"
#       nanoseconds < 1_000_000_000 -> "#{Float.round(nanoseconds / 1_000_000, 1)} ms"
#       true -> "#{Float.round(nanoseconds / 1_000_000_000, 1)} s"
#     end
#   end

#   #############################################################################
#   # Validation Helpers
#   #############################################################################

#   @doc """
#   Validates that a value is a positive integer.

#   ## Examples

#       iex> ElixirScope.Utils.valid_positive_integer?(42)
#       true

#       iex> ElixirScope.Utils.valid_positive_integer?(-1)
#       false
#   """
#   @spec valid_positive_integer?(term()) :: boolean()
#   def valid_positive_integer?(value) do
#     is_integer(value) and value > 0
#   end

#   @doc """
#   Validates that a value is a percentage (0.0 to 1.0).

#   ## Examples

#       iex> ElixirScope.Utils.valid_percentage?(0.5)
#       true

#       iex> ElixirScope.Utils.valid_percentage?(1.5)
#       false
#   """
#   @spec valid_percentage?(term()) :: boolean()
#   def valid_percentage?(value) do
#     is_number(value) and value >= 0 and value <= 1
#   end

#   @doc """
#   Validates that a PID exists and is alive.

#   ## Examples

#       iex> ElixirScope.Utils.valid_pid?(self())
#       true

#       iex> dead_pid = spawn(fn -> nil end)
#       iex> Process.sleep(10)
#       iex> ElixirScope.Utils.valid_pid?(dead_pid)
#       false
#   """
#   @spec valid_pid?(term()) :: boolean()
#   def valid_pid?(value) do
#     is_pid(value) and Process.alive?(value)
#   end

#   ## Private Functions

#   defp get_type_hint(term) do
#     cond do
#       is_binary(term) -> "binary data"
#       is_list(term) -> "list with #{length(term)} elements"
#       is_map(term) -> "map with #{map_size(term)} keys"
#       is_tuple(term) -> "tuple with #{tuple_size(term)} elements"
#       true -> "#{inspect(term.__struct__ || :unknown)} data"
#     end
#   rescue
#     _ -> "complex data structure"
#   end
# end
