defmodule ElixirScope.Foundation.Config.GracefulDegradation do
  @moduledoc """
  Graceful degradation for Config service when GenServer is unavailable.

  Provides fallback configuration access and pending update retry mechanisms
  to maintain service availability during Config GenServer restarts.
  """

  alias ElixirScope.Foundation.{Utils, Config, Error}
  require Logger

  @fallback_table :foundation_config_fallback

  @doc """
  Initialize the fallback system with ETS cache and retry mechanism.
  """
  def initialize_fallback_system do
    # Create ETS table for fallback config storage
    case :ets.whereis(@fallback_table) do
      :undefined ->
        :ets.new(@fallback_table, [:named_table, :public, :set])

      _ ->
        :ok
    end

    Task.start_link(&retry_pending_updates/0)
  end

  @doc """
  Get configuration with fallback to cached values when service unavailable.
  """
  def get_with_fallback(path) do
    case Config.get(path) do
      {:error, %Error{error_type: :service_unavailable}} ->
        get_fallback_config(path)

      value ->
        # Cache successful result
        cache_config_value(path, value)
        value
    end
  end

  @doc """
  Update configuration with fallback to pending retry when service unavailable.
  """
  def update_with_fallback(path, value) do
    case Config.update(path, value) do
      :ok ->
        # Clear cached value on successful update
        clear_cached_value(path)
        :ok

      {:error, %Error{error_type: :service_unavailable}} = error ->
        Logger.error("Config update failed: #{inspect(error)}")
        # Cache the pending update for retry when service returns
        cache_pending_update(path, value)
        error

      other_error ->
        other_error
    end
  end

  # Private implementation

  defp get_fallback_config([]) do
    # Return default config when service unavailable
    case :ets.lookup(@fallback_table, :full_config) do
      [{:full_config, config}] -> config
      [] -> get_default_config()
    end
  end

  defp get_fallback_config(path) do
    case :ets.lookup(@fallback_table, path) do
      [{^path, value}] ->
        value

      [] ->
        # Try to get from default config
        default_config = get_default_config()
        get_in(default_config, path)
    end
  end

  defp cache_config_value(path, value) do
    :ets.insert(@fallback_table, {path, value})
  end

  defp clear_cached_value(path) do
    :ets.delete(@fallback_table, path)
  end

  defp cache_pending_update(path, value) do
    pending_key = {:pending, path}
    :ets.insert(@fallback_table, {pending_key, {value, Utils.wall_timestamp()}})
  end

  defp retry_pending_updates do
    # Wait 5 seconds between retries
    Process.sleep(5000)

    # Get all pending updates
    pending = :ets.match(@fallback_table, {{:pending, :"$1"}, :"$2"})

    Enum.each(pending, fn [path, {value, _timestamp}] ->
      case Config.update(path, value) do
        :ok ->
          Logger.info("Successfully applied pending config update: #{inspect(path)}")
          :ets.delete(@fallback_table, {:pending, path})

        {:error, reason} ->
          Logger.debug("Retry of pending config update failed: #{inspect(reason)}")
      end
    end)

    retry_pending_updates()
  end

  defp get_default_config do
    # Return minimal working configuration for emergency fallback
    %{
      ai: %{
        provider: :mock,
        api_key: nil,
        model: "fallback",
        analysis: %{max_file_size: 100_000, timeout: 5_000, cache_ttl: 300},
        planning: %{default_strategy: :fast, performance_target: 0.1, sampling_rate: 0.1}
      },
      capture: %{
        ring_buffer: %{size: 100, max_events: 1000, overflow_strategy: :drop_oldest, num_buffers: 1},
        processing: %{batch_size: 10, flush_interval: 100, max_queue_size: 100},
        vm_tracing: %{
          enable_spawn_trace: false,
          enable_exit_trace: false,
          enable_message_trace: false,
          trace_children: false
        }
      },
      storage: %{
        hot: %{max_events: 1000, max_age_seconds: 300, prune_interval: 60_000},
        warm: %{enable: false, path: "/tmp", max_size_mb: 10, compression: :none},
        cold: %{enable: false}
      },
      interface: %{query_timeout: 1000, max_results: 100, enable_streaming: false},
      dev: %{debug_mode: false, verbose_logging: false, performance_monitoring: false},
    }
  end
end

defmodule ElixirScope.Foundation.Events.GracefulDegradation do
  @moduledoc """
  Graceful degradation patterns for Event system failures.

  Provides safe event creation, robust serialization with recovery,
  and data corruption recovery mechanisms.
  """

  require Logger
  alias ElixirScope.Foundation.{Events, Utils}

  @doc """
  Create event with safe fallback for failed creation.
  """
  def new_event_safe(event_type, data, opts \\ []) do
    case Events.new_event(event_type, data, opts) do
      {:error, reason} ->
        Logger.debug("Event creation failed (#{inspect(reason)}), creating minimal event")
        create_minimal_event(event_type, data, opts)

      event ->
        event
    end
  end

  @spec serialize_safe(ElixirScope.Foundation.Events.t()) :: binary()
  @doc """
  Serialize event with JSON fallback for failed serialization.
  """
  def serialize_safe(event_or_tuple) do
    IO.puts("🚀 GracefulDegradation.serialize_safe called")
    IO.puts("📥 Input event: #{inspect(event_or_tuple, limit: :infinity)}")

    # Handle both Event structs and {:ok, Event} tuples
    event = case event_or_tuple do
      {:ok, %ElixirScope.Foundation.Types.Event{} = e} -> e
      %ElixirScope.Foundation.Types.Event{} = e -> e
      other -> other
    end

    result =
      case Events.serialize(event) do
        {:error, reason} ->
          IO.puts("⚠️  Events.serialize returned error: #{inspect(reason)}")
          Logger.debug("Event serialization failed (#{inspect(reason)}), using fallback")
          fallback_result = fallback_serialize(event)
          IO.puts("🔄 Fallback result: #{inspect(fallback_result)}")
          fallback_result

        {:ok, binary} ->
          IO.puts("✅ Events.serialize succeeded - binary size: #{byte_size(binary)}")
          binary
      end

    IO.puts("📤 Final serialize_safe result: #{inspect(result)}")
    result
  end

  @doc """
  Deserialize event with recovery for corrupted data.
  """
  def deserialize_safe(binary) do
    case Events.deserialize(binary) do
      {:error, reason} ->
        Logger.debug("Event deserialization failed (#{inspect(reason)}), attempting recovery")
        attempt_recovery_deserialize(binary)

      event ->
        event
    end
  end

  # Private implementation

  defp create_minimal_event(event_type, data, opts) do
    # Create bare minimum event structure
    %{
      event_id: Utils.generate_id(),
      event_type: event_type,
      timestamp: Utils.monotonic_timestamp(),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: Keyword.get(opts, :correlation_id),
      parent_id: Keyword.get(opts, :parent_id),
      data: safe_data_conversion(data)
    }
  end

  defp safe_data_conversion(data) do
    try do
      # Ensure data is serializable
      _test = :erlang.term_to_binary(data)
      data
    rescue
      _ ->
        # Fallback to string representation
        %{safe_representation: inspect(data), original_type: typeof(data)}
    end
  end

  # defp fallback_serialize(event) do
  #   # Simple JSON-like serialization as fallback
  #   try do
  #     event
  #     |> Map.from_struct()
  #     |> Jason.encode!()
  #   rescue
  #     _ ->
  #       # Ultimate fallback
  #       inspect(event)
  #   end
  # end
  # Add this to the GracefulDegradation module for testing
  def test_fallback_serialize(event) do
    IO.puts("🧪 test_fallback_serialize called directly")
    fallback_serialize(event)
  end

  def fallback_serialize(event) do
    IO.puts("🔄 fallback_serialize called")
    IO.puts("📥 Event to fallback serialize: #{inspect(event, limit: :infinity)}")

    result =
      try do
        # Convert struct to map and clean it for JSON
        map_result =
          event
          |> Map.from_struct()
          |> clean_for_json()

        IO.puts("🗺️  Cleaned map result: #{inspect(map_result, limit: :infinity)}")

        json_result = Jason.encode!(map_result)
        IO.puts("📝 Jason.encode! result: #{inspect(json_result)}")
        json_result
      rescue
        error ->
          IO.puts("❌ Jason.encode! failed: #{inspect(error)}")
          # Create a simple JSON structure instead of inspect
          simple_json = %{
            event_type: to_string(event.event_type),
            data: sanitize_data(event.data),
            error: "Fallback serialization - original failed",
            timestamp: DateTime.to_iso8601(event.wall_time)
          }

          fallback_result = Jason.encode!(simple_json)
          IO.puts("🔍 Simple JSON fallback: #{inspect(fallback_result)}")
          fallback_result
      end

    IO.puts("📤 fallback_serialize final result: #{inspect(result)}")
    result
  end

  # Add these helper functions
  defp clean_for_json(map) do
    Map.new(map, fn {key, value} -> {key, sanitize_value(value)} end)
  end

  defp sanitize_value(pid) when is_pid(pid), do: inspect(pid)
  defp sanitize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp sanitize_value(value) when is_map(value), do: clean_for_json(value)
  defp sanitize_value(value), do: value

  defp sanitize_data(data) when is_map(data), do: clean_for_json(data)
  defp sanitize_data(data), do: data

  defp attempt_recovery_deserialize(binary) do
    try do
      # Try JSON decode first
      case Jason.decode(binary) do
        {:ok, map} -> reconstruct_event_from_map(map)
        {:error, _} -> create_error_event(binary)
      end
    rescue
      _ -> create_error_event(binary)
    end
  end

  defp reconstruct_event_from_map(map) do
    # Attempt to reconstruct event from map
    alias ElixirScope.Foundation.Types.Event
    %Event{
      event_id: Map.get(map, "event_id", Utils.generate_id()),
      event_type: String.to_atom(Map.get(map, "event_type", "unknown")),
      timestamp: Map.get(map, "timestamp", Utils.monotonic_timestamp()),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: Map.get(map, "correlation_id"),
      parent_id: Map.get(map, "parent_id"),
      data: Map.get(map, "data", %{recovery: true})
    }
  end

  defp create_error_event(binary) do
    alias ElixirScope.Foundation.Types.Event
    %Event{
      event_id: Utils.generate_id(),
      event_type: :deserialization_error,
      timestamp: Utils.monotonic_timestamp(),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: nil,
      parent_id: nil,
      data: %{
        error: "Failed to deserialize event",
        binary_size: byte_size(binary),
        binary_sample: String.slice(binary, 0, 100)
      }
    }
  end

  defp typeof(value) when is_atom(value), do: :atom
  defp typeof(value) when is_binary(value), do: :string
  defp typeof(value) when is_map(value), do: :map
  defp typeof(value) when is_list(value), do: :list
  defp typeof(_), do: :unknown
end
