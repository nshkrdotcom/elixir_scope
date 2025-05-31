defmodule ElixirScope.Foundation.Utils do
  @moduledoc """
  Core utility functions for ElixirScope Foundation layer.

  Provides essential utilities for ID generation, time measurement,
  data inspection, and performance monitoring.
  """

  import Bitwise
  alias ElixirScope.Foundation.{Types}

  @type measurement_result(t) :: {t, non_neg_integer()}

  ## ID Generation

  @spec generate_id() :: Types.event_id()
  def generate_id do
    # Use a combination of timestamp and random value for uniqueness
    timestamp = System.monotonic_time(:nanosecond)
    random = :rand.uniform(1_000_000)

    # Combine timestamp and random for globally unique ID
    # Use abs to handle negative monotonic time
    abs(timestamp) * 1_000_000 + random
  end

  @spec generate_correlation_id() :: Types.correlation_id()
  def generate_correlation_id do
    # Generate UUID v4 format
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)

    # Set version (4) and variant bits
    u2_v4 = (u2 &&& 0x0FFF) ||| 0x4000
    u3_var = (u3 &&& 0x3FFF) ||| 0x8000

    :io_lib.format(
      "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
      [u0, u1, u2_v4, u3_var, u4]
    )
    |> IO.iodata_to_binary()
  end

  @spec id_to_timestamp(Types.event_id()) :: Types.timestamp()
  def id_to_timestamp(id) when is_integer(id) do
    # Extract timestamp component from ID
    div(id, 1_000_000)
  end

  ## Time Utilities

  @spec monotonic_timestamp() :: Types.timestamp()
  def monotonic_timestamp do
    System.monotonic_time(:nanosecond)
  end

  @spec wall_timestamp() :: Types.timestamp()
  def wall_timestamp do
    System.os_time(:nanosecond)
  end

  @spec format_timestamp(Types.timestamp()) :: String.t()
  def format_timestamp(timestamp_ns) when is_integer(timestamp_ns) do
    timestamp_us = div(timestamp_ns, 1_000)
    datetime = DateTime.from_unix!(timestamp_us, :microsecond)

    # Format with nanosecond precision
    nanoseconds = rem(timestamp_ns, 1_000_000)
    formatted_base = DateTime.to_iso8601(datetime)

    # Replace microseconds with full nanosecond precision
    String.replace(formatted_base, ~r/\.\d{6}/, ".#{:io_lib.format("~6..0B", [nanoseconds])}")
  end

  ## Measurement

  @spec measure((-> t)) :: measurement_result(t) when t: var
  def measure(fun) when is_function(fun, 0) do
    start_time = monotonic_timestamp()
    result = fun.()
    end_time = monotonic_timestamp()

    {result, end_time - start_time}
  end

  @spec measure_memory((-> t)) :: {t, {non_neg_integer(), non_neg_integer(), integer()}} when t: var
  def measure_memory(fun) when is_function(fun, 0) do
    memory_before = :erlang.memory(:total)
    result = fun.()
    memory_after = :erlang.memory(:total)

    {result, {memory_before, memory_after, memory_after - memory_before}}
  end

  ## Data Inspection

  @spec safe_inspect(term(), keyword()) :: String.t()
  def safe_inspect(term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    inspect(term, limit: limit, printable_limit: 100, pretty: true)
  end

  @spec truncate_if_large(term(), non_neg_integer()) :: term() | Types.truncated_data()
  def truncate_if_large(term, size_limit \\ 1000) do
    estimated_size = term_size(term)

    if estimated_size <= size_limit do
      term
    else
      type_hint = get_type_hint(term)
      {:truncated, estimated_size, type_hint}
    end
  end

  @spec term_size(term()) :: non_neg_integer()
  def term_size(term) do
    :erlang.external_size(term)
  end

  ## Process and System Stats

  @spec process_stats(pid()) :: map()
  def process_stats(pid \\ self()) do
    case Process.info(pid, [:memory, :reductions, :message_queue_len]) do
      nil ->
        %{error: :process_not_found, timestamp: monotonic_timestamp()}

      info ->
        info
        |> Keyword.put(:timestamp, monotonic_timestamp())
        |> Enum.into(%{})
    end
  end

  @spec system_stats() :: %{
          timestamp: integer(),
          process_count: non_neg_integer(),
          total_memory: non_neg_integer(),
          scheduler_count: pos_integer(),
          otp_release: binary()
        }
  def system_stats do
    %{
      timestamp: monotonic_timestamp(),
      process_count: :erlang.system_info(:process_count),
      total_memory: :erlang.memory(:total),
      scheduler_count: :erlang.system_info(:schedulers),
      otp_release: :erlang.system_info(:otp_release) |> List.to_string()
    }
  end

  ## Formatting

  @spec format_bytes(non_neg_integer()) :: String.t()
  def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  @spec format_duration(non_neg_integer()) :: String.t()
  def format_duration(nanoseconds) when is_integer(nanoseconds) and nanoseconds >= 0 do
    cond do
      nanoseconds < 1_000 -> "#{nanoseconds} ns"
      nanoseconds < 1_000_000 -> "#{Float.round(nanoseconds / 1_000, 1)} μs"
      nanoseconds < 1_000_000_000 -> "#{Float.round(nanoseconds / 1_000_000, 1)} ms"
      true -> "#{Float.round(nanoseconds / 1_000_000_000, 1)} s"
    end
  end

  ## Validation

  @spec valid_positive_integer?(term()) :: boolean()
  def valid_positive_integer?(value) do
    is_integer(value) and value > 0
  end

  @spec valid_percentage?(term()) :: boolean()
  def valid_percentage?(value) do
    is_number(value) and value >= 0 and value <= 1
  end

  @spec valid_pid?(term()) :: boolean()
  def valid_pid?(value) do
    is_pid(value) and Process.alive?(value)
  end

  ## Private Functions

  @spec get_type_hint(term()) :: String.t()
  defp get_type_hint(term) do
    cond do
      is_binary(term) -> "binary data"
      is_list(term) -> "list with #{length(term)} elements"
      is_map(term) -> "map with #{map_size(term)} keys"
      is_tuple(term) -> "tuple with #{tuple_size(term)} elements"
      true -> "#{inspect(term.__struct__ || :unknown)} data"
    end
  rescue
    _ -> "complex data structure"
  end
end
