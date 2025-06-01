defmodule ElixirScope.Foundation.Property.StateAccumulationTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  
  alias ElixirScope.Foundation.{Telemetry}
  alias ElixirScope.Foundation.Services.TelemetryService
  
  defp timestamp_ms, do: System.monotonic_time(:millisecond)
  
  defp timestamp_log(message) do
    IO.puts("[#{DateTime.utc_now() |> DateTime.to_string()}] #{message}")
    timestamp_ms()
  end

  # Test 1: Simulate the state accumulation that causes slowdowns
  test "STATE ACCUMULATION: Reproduce 32-second delay through metric buildup" do
    start_time = timestamp_log("=== TESTING STATE ACCUMULATION SLOWDOWN ===")
    
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    
    # Simulate what happens across 36 tests with multiple property runs each
    iterations = [10, 50, 100, 500, 1000, 2000]  # Simulate growing metric counts
    
    for iteration_count <- iterations do
      iter_start = timestamp_ms()
      timestamp_log("=== ITERATION #{iteration_count}: Adding #{iteration_count} metrics ===")
      
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
      
      timestamp_log("ITERATION #{iteration_count} RESULTS:")
      timestamp_log("  - Operations (#{iteration_count} ops): #{operation_duration}ms")
      timestamp_log("  - Get metrics: #{metrics_duration}ms")
      timestamp_log("  - Verification: #{verify_duration}ms") 
      timestamp_log("  - Total metrics in system: #{total_metrics}")
      timestamp_log("  - Total iteration time: #{total_iter_duration}ms")
      
      # Check if we've hit the slowdown threshold
      if total_iter_duration > 5000 do
        timestamp_log("*** FOUND THE BOTTLENECK: #{iteration_count} operations took #{total_iter_duration}ms ***")
        timestamp_log("*** This explains the 32-second delay! ***")
      end
      
      if metrics_duration > 1000 do
        timestamp_log("*** GET_METRICS IS SLOW: #{metrics_duration}ms with #{total_metrics} metrics ***")
      end
      
      if verify_duration > 1000 do
        timestamp_log("*** VERIFICATION IS SLOW: #{verify_duration}ms with #{total_metrics} metrics ***")
      end
    end
    
    end_time = timestamp_ms()
    total_duration = end_time - start_time
    timestamp_log("=== STATE ACCUMULATION TEST COMPLETE: #{total_duration}ms ===")
    
    if total_duration > 30000 do
      timestamp_log("*** REPRODUCED THE 32-SECOND DELAY! ***")
    end
  end

  # Test 2: Test with proper state reset vs without reset
  test "STATE RESET: Compare performance with and without proper cleanup" do
    start_time = timestamp_log("=== TESTING STATE RESET IMPACT ===")
    
    # Test WITHOUT proper reset (accumulating state)
    timestamp_log("--- Testing WITHOUT state reset ---")
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
      
      total_metrics = count_all_metrics(metrics)
      timestamp_log("Run #{run} (no reset): get_metrics=#{get_duration}ms, total_metrics=#{total_metrics}")
    end
    
    no_reset_end = timestamp_ms()
    no_reset_duration = no_reset_end - no_reset_start
    
    # Test WITH proper reset (clean state)
    timestamp_log("--- Testing WITH state reset ---")
    
    # Restart service to clear state
    if Process.whereis(TelemetryService) do
      GenServer.stop(TelemetryService, :normal, 1000)
      Process.sleep(100)
    end
    {:ok, _} = TelemetryService.start_link([])
    
    reset_start = timestamp_ms()
    
    for run <- 1..5 do
      # Restart service each run (like proper test isolation)
      GenServer.stop(TelemetryService, :normal, 1000)
      {:ok, _} = TelemetryService.start_link([])
      
      # Add same metrics but with clean state
      for i <- 1..100 do
        Telemetry.emit_counter([:test, :with_reset, run], %{increment: 1})
        Telemetry.emit_gauge([:test, :gauge, run], i * 10.0, %{})
      end
      
      # Measure get_metrics performance
      get_start = timestamp_ms()
      {:ok, metrics} = Telemetry.get_metrics()
      get_end = timestamp_ms()
      get_duration = get_end - get_start
      
      total_metrics = count_all_metrics(metrics)
      timestamp_log("Run #{run} (with reset): get_metrics=#{get_duration}ms, total_metrics=#{total_metrics}")
    end
    
    reset_end = timestamp_ms()
    reset_duration = reset_end - reset_start
    
    timestamp_log("=== STATE RESET COMPARISON ===")
    timestamp_log("Without reset: #{no_reset_duration}ms")
    timestamp_log("With reset: #{reset_duration}ms")
    timestamp_log("Difference: #{no_reset_duration - reset_duration}ms")
    
    if no_reset_duration > reset_duration * 2 do
      timestamp_log("*** STATE ACCUMULATION CONFIRMED AS BOTTLENECK ***")
    end
    
    end_time = timestamp_ms()
    timestamp_log("=== STATE RESET TEST COMPLETE: #{end_time - start_time}ms ===")
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