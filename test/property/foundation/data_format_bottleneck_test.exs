defmodule ElixirScope.Foundation.Property.DataFormatBottleneckTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  # Property tests are inherently slow
  @moduletag :slow

  alias ElixirScope.Foundation.{Telemetry}
  alias ElixirScope.Foundation.Services.TelemetryService

  # Timing utilities
  defp timestamp_ms, do: System.monotonic_time(:millisecond)

  defp timestamp_log(message) do
    if System.get_env("VERBOSE_TEST_LOGS") == "true" do
      IO.puts("[#{DateTime.utc_now() |> DateTime.to_string()}] #{message}")
    end

    timestamp_ms()
  end

  setup do
    # Only log setup if verbose mode
    if System.get_env("VERBOSE_TEST_LOGS") == "true" do
      timestamp_log("=== SETUP START ===")
    end

    # Reset state more aggressively like original tests
    try do
      if Process.whereis(TelemetryService) do
        GenServer.stop(TelemetryService, :normal, 1000)
        Process.sleep(100)
      end
    rescue
      _ -> :ok
    end

    # Handle already started case
    case TelemetryService.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Process.sleep(50)

    if System.get_env("VERBOSE_TEST_LOGS") == "true" do
      timestamp_log("=== SETUP COMPLETE ===")
    end

    :ok
  end

  # Test 1: Reproduce the exact original test with Telemetry module (not TelemetryService)
  property "DATA FORMAT TEST: Original test using Telemetry module" do
    start_time = timestamp_log("=== STARTING ORIGINAL DATA FORMAT TEST ===")

    # Use the exact same operations that were failing in original tests
    operations = [
      {:gauge, [:A], 1000.0, %{}},
      {:gauge, [:foundation, :config_updates], 0, %{}},
      {:counter, [:foundation, :config_updates], 1, %{}},
      {:gauge, [:foundation, :config_updates], 0, %{}},
      {:counter, [:foundation, :config_updates], 1, %{}}
    ]

    check all(
            _dummy <- StreamData.constant(:ok),
            max_runs: 1
          ) do
      run_start = timestamp_ms()
      timestamp_log("Testing with original Telemetry module calls")

      # Execute operations using Telemetry module (like original tests)
      exec_start = timestamp_ms()

      Enum.each(operations, fn {type, path, value, metadata} ->
        case type do
          :counter ->
            # This is the original failing call pattern
            :ok = Telemetry.emit_counter(path, Map.put(metadata, :increment, value))

          :gauge ->
            # This is the original failing call pattern  
            :ok = Telemetry.emit_gauge(path, value, metadata)
        end
      end)

      exec_end = timestamp_ms()
      timestamp_log("Operations execution took: #{exec_end - exec_start}ms")

      # Get metrics using Telemetry module (like original)
      metrics_start = timestamp_ms()
      {:ok, metrics} = Telemetry.get_metrics()
      metrics_end = timestamp_ms()
      timestamp_log("Get metrics took: #{metrics_end - metrics_start}ms")

      # Do the exact verification that was failing in original tests
      verify_start = timestamp_ms()
      timestamp_log("Starting verification that was slow in original tests...")

      # This is the exact verification from original failing tests
      Enum.each(metrics, fn {key, value} ->
        key_start = timestamp_ms()

        # This was causing the "Metric key should be atom" error
        if not (is_atom(key) or is_binary(key) or is_integer(key)) do
          timestamp_log("SLOW: Found problematic key: #{inspect(key)} of type #{typeof(key)}")
        end

        # This was causing the String.Chars protocol error
        try do
          _string_value = to_string(value)
        rescue
          Protocol.UndefinedError ->
            timestamp_log("SLOW: Cannot convert to string: #{inspect(value)}")
        end

        # This was causing the assertion failures with complex structures
        if is_map(value) do
          if Map.has_key?(value, :measurements) do
            measurements = value.measurements

            Enum.each(measurements, fn {_measurement_key, measurement_value} ->
              # Check if this is the problematic pattern
              if is_number(measurement_value) and measurement_value != measurement_value do
                timestamp_log("SLOW: Found NaN or complex number: #{inspect(measurement_value)}")
              end
            end)
          end
        end

        key_end = timestamp_ms()

        if key_end - key_start > 5 do
          timestamp_log("SLOW: Key #{inspect(key)} verification took #{key_end - key_start}ms")
        end
      end)

      verify_end = timestamp_ms()
      timestamp_log("Verification took: #{verify_end - verify_start}ms")

      run_end = timestamp_ms()
      timestamp_log("Total run duration: #{run_end - run_start}ms")

      # This should succeed without the data format errors
      assert is_map(metrics)
    end

    end_time = timestamp_ms()
    timestamp_log("=== ORIGINAL DATA FORMAT TEST COMPLETE: #{end_time - start_time}ms ===")
  end

  # Test 2: Compare direct TelemetryService vs Telemetry wrapper performance  
  test "PERFORMANCE TEST: TelemetryService vs Telemetry wrapper comparison" do
    start_time = timestamp_log("=== STARTING PERFORMANCE COMPARISON ===")

    operations = [
      {:gauge, [:A], 1000.0, %{}},
      {:counter, [:foundation, :config_updates], 1, %{}}
    ]

    # Test direct TelemetryService calls
    direct_start = timestamp_ms()

    Enum.each(operations, fn {type, path, value, metadata} ->
      case type do
        :counter -> TelemetryService.emit_counter(path, metadata)
        :gauge -> TelemetryService.emit_gauge(path, value, metadata)
      end
    end)

    {:ok, _direct_metrics} = TelemetryService.get_metrics()
    direct_end = timestamp_ms()
    direct_duration = direct_end - direct_start
    timestamp_log("Direct TelemetryService calls took: #{direct_duration}ms")

    # Test Telemetry wrapper calls  
    wrapper_start = timestamp_ms()

    Enum.each(operations, fn {type, path, value, metadata} ->
      case type do
        :counter -> Telemetry.emit_counter(path, Map.put(metadata, :increment, value))
        :gauge -> Telemetry.emit_gauge(path, value, metadata)
      end
    end)

    {:ok, _wrapper_metrics} = Telemetry.get_metrics()
    wrapper_end = timestamp_ms()
    wrapper_duration = wrapper_end - wrapper_start
    timestamp_log("Telemetry wrapper calls took: #{wrapper_duration}ms")

    timestamp_log("Performance difference: #{wrapper_duration - direct_duration}ms")

    end_time = timestamp_ms()
    timestamp_log("=== PERFORMANCE COMPARISON COMPLETE: #{end_time - start_time}ms ===")
  end

  # Test 3: Test the specific data structure verification that was slow
  test "VERIFICATION TEST: Reproduce slow structure verification" do
    start_time = timestamp_log("=== STARTING SLOW VERIFICATION TEST ===")

    # Create some metrics with the problematic data patterns
    TelemetryService.emit_gauge([:A], 1000.0, %{})
    TelemetryService.emit_counter([:foundation, :config_updates], %{})
    {:ok, metrics} = TelemetryService.get_metrics()

    timestamp_log("Retrieved metrics with #{map_size(metrics)} keys")
    timestamp_log("Metrics structure: #{inspect(metrics, limit: :infinity)}")

    # Test the exact verification function that was slow in original
    verification_start = timestamp_ms()
    verify_metrics_structure_original(metrics)
    verification_end = timestamp_ms()
    verification_duration = verification_end - verification_start

    timestamp_log("Structure verification took: #{verification_duration}ms")

    if verification_duration > 50 do
      timestamp_log("WARNING: Verification was slow! This explains the 32-second delay.")
    end

    end_time = timestamp_ms()
    timestamp_log("=== SLOW VERIFICATION TEST COMPLETE: #{end_time - start_time}ms ===")
  end

  # Helper function that replicates the original failing verification
  defp verify_metrics_structure_original(metrics) when is_map(metrics) do
    timestamp_log("Starting original structure verification...")

    Enum.each(metrics, fn {key, value} ->
      # This was the original failing assertion
      assert is_atom(key), "Metric key should be atom, got #{inspect(key)}"

      # This was causing Protocol.UndefinedError
      try do
        case value do
          v when is_number(v) ->
            :ok

          v when is_map(v) ->
            verify_metrics_structure_original(v)

          v when is_boolean(v) ->
            :ok

          v when is_binary(v) ->
            :ok

          v when is_atom(v) ->
            :ok

          other ->
            timestamp_log("Unexpected value type: #{inspect(other)}")
            flunk("Invalid metric value type: #{inspect(other)}")
        end
      rescue
        error ->
          timestamp_log("Error during verification: #{inspect(error)}")
          reraise error, __STACKTRACE__
      end
    end)
  end

  # Helper to identify data types
  defp typeof(value) when is_integer(value), do: :integer
  defp typeof(value) when is_float(value), do: :float
  defp typeof(value) when is_boolean(value), do: :boolean
  defp typeof(value) when is_binary(value), do: :binary
  defp typeof(value) when is_atom(value), do: :atom
  defp typeof(value) when is_list(value), do: :list
  defp typeof(value) when is_map(value), do: :map
  defp typeof(_), do: :unknown
end
