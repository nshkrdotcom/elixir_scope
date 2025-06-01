defmodule ElixirScope.Foundation.Property.StateAccumulationTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  
  alias ElixirScope.Foundation.{Telemetry}
  alias ElixirScope.Foundation.Services.TelemetryService
  
  defp timestamp_ms, do: System.monotonic_time(:millisecond)
  
  # Conditional logging - only log if verbose mode or significant issues
  defp timestamp_log(message, force) do
    verbose = System.get_env("VERBOSE_TEST_LOGS") == "true"
    if verbose or force do
      IO.puts("[#{DateTime.utc_now() |> DateTime.to_string()}] #{message}")
    end
    timestamp_ms()
  end

  # Test 1: Simulate the state accumulation that causes slowdowns
  test "STATE ACCUMULATION: Reproduce 32-second delay through metric buildup" do
    start_time = timestamp_log("=== TESTING STATE ACCUMULATION SLOWDOWN ===", true)
    
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    
    # Simulate what happens across 36 tests with multiple property runs each
    iterations = [10, 50, 100, 500, 1000, 2000]  # Simulate growing metric counts
    
    for iteration_count <- iterations do
      iter_start = timestamp_ms()
      # Only log every few iterations or when count is high
      should_log = iteration_count >= 500 or rem(iteration_count, 50) == 0
      timestamp_log("=== ITERATION #{iteration_count}: Adding #{iteration_count} metrics ===", should_log)
      
      # Add lots of metrics (simulating multiple test runs)
      operation_start = timestamp_ms()
      for i <- 1..iteration_count do
        # These are the exact same operations causing slowdowns in original tests
        Telemetry.emit_counter([:foundation, :config_updates], %{increment: 1})
        Telemetry.emit_gauge([:A], 1000.0, %{})
        
        # Add some variety like the property tests
        if rem(i, 10) == 0 do
          Telemetry.emit_gauge([:foundation, :config_updates], 0, %{})
          Telemetry.emit_counter([:foundation, :events_stored], %{increment: 1})
        end
      end
      operation_end = timestamp_ms()
      operation_duration = operation_end - operation_start
      
      # Get metrics (this should slow down as state grows)
      metrics_start = timestamp_ms()
      {:ok, metrics} = Telemetry.get_metrics()
      metrics_end = timestamp_ms()
      metrics_duration = metrics_end - metrics_start
      
      # Count total metrics
      total_metrics = count_all_metrics(metrics)
      
      # Verify structure (this should slow down with more metrics)
      verify_start = timestamp_ms()
      verify_metrics_structure(metrics)
      verify_end = timestamp_ms()
      verify_duration = verify_end - verify_start
      
      iter_end = timestamp_ms()
      total_iter_duration = iter_end - iter_start
      
      # Only log details if slow or forced
      if should_log or total_iter_duration > 2000 do
        timestamp_log("ITERATION #{iteration_count} RESULTS:", true)
        timestamp_log("  - Operations (#{iteration_count} ops): #{operation_duration}ms", true)
        timestamp_log("  - Get metrics: #{metrics_duration}ms", true)
        timestamp_log("  - Verification: #{verify_duration}ms", true) 
        timestamp_log("  - Total metrics in system: #{total_metrics}", true)
        timestamp_log("  - Total iteration time: #{total_iter_duration}ms", true)
      end
      
      # Check if we've hit the slowdown threshold
      if total_iter_duration > 5000 do
        timestamp_log("*** FOUND THE BOTTLENECK: #{iteration_count} operations took #{total_iter_duration}ms ***", true)
        timestamp_log("*** This explains the 32-second delay! ***", true)
      end
      
      if metrics_duration > 1000 do
        timestamp_log("*** GET_METRICS IS SLOW: #{metrics_duration}ms with #{total_metrics} metrics ***", true)
      end
      
      if verify_duration > 1000 do
        timestamp_log("*** VERIFICATION IS SLOW: #{verify_duration}ms with #{total_metrics} metrics ***", true)
      end
    end
    
    end_time = timestamp_ms()
    total_duration = end_time - start_time
    timestamp_log("=== STATE ACCUMULATION TEST COMPLETE: #{total_duration}ms ===", true)
    
    if total_duration > 30000 do
      timestamp_log("*** REPRODUCED THE 32-SECOND DELAY! ***", true)
    end
  end

  # Test 2: Test with proper state reset vs without reset
  test "STATE RESET: Compare performance with and without proper cleanup" do
    start_time = timestamp_log("=== TESTING STATE RESET IMPACT ===", true)
    
    # Test WITHOUT proper reset (accumulating state)
    no_reset_start = timestamp_ms()
    
    for run <- 1..5 do
      # Add metrics without reset
      for i <- 1..100 do
        Telemetry.emit_counter([:test, :no_reset, run], %{increment: 1})
        Telemetry.emit_gauge([:test, :gauge, run], i * 10.0, %{})
      end
      
      # Measure get_metrics performance
      get_start = timestamp_ms()
      {:ok, metrics} = Telemetry.get_metrics()
      get_end = timestamp_ms()
      get_duration = get_end - get_start
      
      _total_metrics = count_all_metrics(metrics)
      # Only log if very slow
      if get_duration > 100 do
        timestamp_log("Run #{run} (no reset): SLOW get_metrics=#{get_duration}ms", true)
      end
    end
    
    no_reset_end = timestamp_ms()
    no_reset_duration = no_reset_end - no_reset_start
    
    # Test WITH proper reset (clean state)
    
    # Restart service to clear state - handle already started case
    if Process.whereis(TelemetryService) do
      GenServer.stop(TelemetryService, :normal, 1000)
      Process.sleep(100)
    end
    
    case TelemetryService.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    reset_start = timestamp_ms()
    
    for run <- 1..5 do
      # Restart service each run (like proper test isolation) - handle already started
      if Process.whereis(TelemetryService) do
        GenServer.stop(TelemetryService, :normal, 1000)
      end
      
      case TelemetryService.start_link([]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end
      
      # Add same metrics but with clean state
      for i <- 1..100 do
        Telemetry.emit_counter([:test, :with_reset, run], %{increment: 1})
        Telemetry.emit_gauge([:test, :gauge, run], i * 10.0, %{})
      end
      
      # Measure get_metrics performance
      get_start = timestamp_ms()
      {:ok, _metrics} = Telemetry.get_metrics()
      get_end = timestamp_ms()
      get_duration = get_end - get_start
      
      # Only log if very slow
      if get_duration > 100 do
        timestamp_log("Run #{run} (with reset): SLOW get_metrics=#{get_duration}ms", true)
      end
    end
    
    reset_end = timestamp_ms()
    reset_duration = reset_end - reset_start
    
    # Only report if there's a significant difference
    if no_reset_duration > reset_duration * 2 do
      timestamp_log("*** STATE ACCUMULATION CONFIRMED: #{no_reset_duration}ms vs #{reset_duration}ms ***", true)
    end
    
    end_time = timestamp_ms()
    total_test_duration = end_time - start_time
    # Only log if test was slow
    if total_test_duration > 1000 do
      timestamp_log("=== STATE RESET TEST COMPLETE: #{total_test_duration}ms ===", true)
    end
  end

  # Helper to count all metrics recursively
  defp count_all_metrics(metrics) when is_map(metrics) do
    Enum.reduce(metrics, 0, fn {_key, value}, acc ->
      case value do
        v when is_map(v) -> acc + 1 + count_all_metrics(v)
        _ -> acc + 1
      end
    end)
  end

  # Helper to verify metrics (same as original tests)
  defp verify_metrics_structure(metrics) when is_map(metrics) do
    Enum.each(metrics, fn {key, value} ->
      # Same verification as original failing tests
      assert is_atom(key) or is_binary(key) or is_integer(key) or is_list(key),
        "Invalid key type: #{inspect(key)}"
      
      case value do
        v when is_number(v) -> :ok
        v when is_map(v) -> verify_metrics_structure(v)  # Recursive call
        v when is_boolean(v) -> :ok
        v when is_binary(v) -> :ok
        v when is_atom(v) -> :ok
        _ -> :ok
      end
    end)
  end
end 