defmodule ElixirScope.Foundation.Property.PerformanceDebugTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  
  alias ElixirScope.Foundation.Services.TelemetryService
  
  # Comprehensive timing utilities
  defp timestamp_ms do
    System.monotonic_time(:millisecond)
  end
  
  defp timestamp_log(message, start_time \\ nil) do
    now = timestamp_ms()
    duration_info = if start_time, do: " (+#{now - start_time}ms)", else: ""
    if System.get_env("VERBOSE_TEST_LOGS") == "true" do
      IO.puts("[#{DateTime.utc_now() |> DateTime.to_string()}#{duration_info}] #{message}")
    end
    now
  end
  
  defp time_operation(name, fun) do
    start_time = timestamp_ms()
    timestamp_log("STARTING: #{name}")
    
    try do
      result = fun.()
      end_time = timestamp_ms()
      duration = end_time - start_time
      timestamp_log("SUCCESS: #{name} completed in #{duration}ms")
      {result, duration}
    rescue
      error ->
        end_time = timestamp_ms()
        duration = end_time - start_time
        timestamp_log("ERROR: #{name} failed in #{duration}ms with #{inspect(error)}")
        reraise error, __STACKTRACE__
    end
  end

  # Test individual operations to find bottlenecks
  test "Performance profiling: Service startup time" do
    timestamp_log("=== SERVICE STARTUP PROFILING ===")
    
    # Stop existing service
    if Process.whereis(TelemetryService) do
      {_, duration} = time_operation("Service stop", fn ->
        GenServer.stop(TelemetryService, :normal, 5000)
      end)
      timestamp_log("Service stop took #{duration}ms")
      Process.sleep(100)  # Wait for cleanup
    end
    
    # Start service fresh
    {result, startup_duration} = time_operation("Service startup", fn ->
      TelemetryService.start_link([])
    end)
    
    case result do
      {:ok, _pid} -> 
        timestamp_log("Service startup: #{startup_duration}ms")
        assert startup_duration < 1000, "Service startup took too long: #{startup_duration}ms"
      {:error, {:already_started, _pid}} ->
        timestamp_log("Service was already started - this is OK for timing: #{startup_duration}ms")
    end
  end

  test "Performance profiling: Basic telemetry operations" do
    timestamp_log("=== BASIC TELEMETRY PROFILING ===")
    
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    
    # Single counter emit
    {_, counter_duration} = time_operation("Single counter emit", fn ->
      TelemetryService.emit_counter([:test, :counter], %{})
    end)
    
    # Single gauge emit - FIXED: value before metadata
    {_, gauge_duration} = time_operation("Single gauge emit", fn ->
      TelemetryService.emit_gauge([:test, :gauge], 42.0, %{})
    end)
    
    # Get metrics - FIXED: handle {:ok, metrics} return
    {metrics_result, metrics_duration} = time_operation("Get metrics", fn ->
      TelemetryService.get_metrics()
    end)
    
    {:ok, metrics} = metrics_result
    
    timestamp_log("Counter emit: #{counter_duration}ms")
    timestamp_log("Gauge emit: #{gauge_duration}ms")
    timestamp_log("Get metrics: #{metrics_duration}ms")
    timestamp_log("Metrics size: #{map_size(metrics)} keys")
    
    assert counter_duration < 100, "Counter emit too slow: #{counter_duration}ms"
    assert gauge_duration < 100, "Gauge emit too slow: #{gauge_duration}ms"
    assert metrics_duration < 100, "Get metrics too slow: #{metrics_duration}ms"
  end

  test "Performance profiling: Property test shrinking simulation" do
    timestamp_log("=== SHRINKING SIMULATION PROFILING ===")
    
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    
    # Simulate what happens during property test shrinking
    operations = [
      {:gauge, [:A], 1000.0, %{}},
      {:gauge, [:foundation, :config_updates], 0.0, %{}},
      {:counter, [:foundation, :config_updates], 1, %{}},
      {:gauge, [:foundation, :config_updates], 0.0, %{}},
      {:counter, [:foundation, :config_updates], 1, %{}}
    ]
    
    timestamp_log("Simulating shrinking with #{length(operations)} operations")
    
    # Execute operations multiple times (simulating shrinking attempts)
    total_start = timestamp_ms()
    
    for attempt <- 1..5 do
      attempt_start = timestamp_ms()
      timestamp_log("Shrinking attempt #{attempt}")
      
      # Execute all operations - FIXED: correct API calls
      {_, exec_duration} = time_operation("Execute operations batch", fn ->
        Enum.each(operations, fn {type, path, value, metadata} ->
          case type do
            :counter -> TelemetryService.emit_counter(path, metadata)
            :gauge -> TelemetryService.emit_gauge(path, value, metadata)  # value before metadata
          end
        end)
      end)
      
      # Get and analyze metrics - FIXED: handle return tuple
      {metrics_result, get_duration} = time_operation("Get metrics for verification", fn ->
        TelemetryService.get_metrics()
      end)
      
      {:ok, metrics} = metrics_result
      
      {_, verify_duration} = time_operation("Verify metrics structure", fn ->
        verify_complex_metrics_structure(metrics)
      end)
      
      attempt_end = timestamp_ms()
      attempt_total = attempt_end - attempt_start
      
      timestamp_log("Attempt #{attempt}: exec=#{exec_duration}ms, get=#{get_duration}ms, verify=#{verify_duration}ms, total=#{attempt_total}ms")
      
      if attempt_total > 1000 do
        timestamp_log("WARNING: Attempt #{attempt} took over 1 second!")
      end
    end
    
    total_end = timestamp_ms()
    total_duration = total_end - total_start
    timestamp_log("Total shrinking simulation: #{total_duration}ms")
    
    assert total_duration < 10000, "Shrinking simulation too slow: #{total_duration}ms"
  end

  test "Performance profiling: Service restart during failure" do
    timestamp_log("=== SERVICE RESTART PROFILING ===")
    
    # Simulate what happens when a test fails and needs to restart services
    restart_start = timestamp_ms()
    
    # Stop service
    {_, stop_duration} = time_operation("Service stop", fn ->
      if Process.whereis(TelemetryService) do
        GenServer.stop(TelemetryService, :normal, 5000)
      end
    end)
    
    # Wait period (simulating cleanup)
    {_, wait_duration} = time_operation("Wait period", fn ->
      Process.sleep(100)
    end)
    
    # Restart service
    {_, start_duration} = time_operation("Service restart", fn ->
      {:ok, _pid} = TelemetryService.start_link([])
    end)
    
    # Initial operations post-restart - FIXED: handle return values
    {_, init_duration} = time_operation("Post-restart operations", fn ->
      TelemetryService.emit_counter([:test, :post_restart], %{})
      {:ok, _metrics} = TelemetryService.get_metrics()
    end)
    
    restart_end = timestamp_ms()
    total_restart = restart_end - restart_start
    
    timestamp_log("Restart breakdown: stop=#{stop_duration}ms, wait=#{wait_duration}ms, start=#{start_duration}ms, init=#{init_duration}ms")
    timestamp_log("Total restart cycle: #{total_restart}ms")
    
    assert total_restart < 5000, "Service restart cycle too slow: #{total_restart}ms"
  end

  test "Performance profiling: Complex metrics structure verification" do
    timestamp_log("=== METRICS VERIFICATION PROFILING ===")
    
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    
    # Generate some complex metrics data - FIXED: correct API calls
    {_, setup_duration} = time_operation("Setup complex metrics", fn ->
      for i <- 1..10 do
        TelemetryService.emit_counter([:complex, :path, i], %{metadata: %{nested: %{deep: i}}})
        TelemetryService.emit_gauge([:complex, :gauge, i], i * 10.0, %{metadata: %{value: i}})
      end
    end)
    
    # Get the metrics - FIXED: handle return tuple
    {metrics_result, get_duration} = time_operation("Get complex metrics", fn ->
      TelemetryService.get_metrics()
    end)
    
    {:ok, metrics} = metrics_result
    
    timestamp_log("Retrieved #{map_size(metrics)} metric entries")
    
    # Verify structure (this is where slowdown might happen)
    {_, verify_duration} = time_operation("Verify complex structure", fn ->
      verify_complex_metrics_structure(metrics)
    end)
    
    timestamp_log("Setup: #{setup_duration}ms, Get: #{get_duration}ms, Verify: #{verify_duration}ms")
    
    assert verify_duration < 1000, "Metrics verification too slow: #{verify_duration}ms"
  end

  # Property test with minimal work to isolate shrinking overhead
  property "Minimal property test to isolate shrinking overhead" do
    timestamp_log("=== MINIMAL PROPERTY TEST ===")
    
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    
    check all value <- StreamData.integer(1..5),
              max_runs: 3 do
      
      test_start = timestamp_ms()
      timestamp_log("Property run with value: #{value}")
      
      # Minimal work
      {_, work_duration} = time_operation("Minimal work", fn ->
        TelemetryService.emit_counter([:minimal, :test], %{})
      end)
      
      # Simple assertion that might fail to trigger shrinking
      if value > 3 do
        timestamp_log("This should trigger shrinking when value > 3")
        # Uncomment to test shrinking behavior:
        # assert false, "Intentional failure to test shrinking (value=#{value})"
      end
      
      test_end = timestamp_ms()
      test_duration = test_end - test_start
      timestamp_log("Property run completed in #{test_duration}ms")
      
      assert work_duration < 50, "Even minimal work too slow: #{work_duration}ms"
    end
  end

  # Helper to verify metrics structure with timing
  defp verify_complex_metrics_structure(metrics) do
    start_time = timestamp_ms()
    
    Enum.each(metrics, fn {key, value} ->
      key_check_start = timestamp_ms()
      
      # Check key type
      assert is_atom(key) or is_binary(key) or is_integer(key) or is_list(key),
        "Invalid key type: #{inspect(key)}"
      
      # Check value structure
      cond do
        is_map(value) ->
          if Map.has_key?(value, :measurements) do
            assert is_map(value.measurements)
          end
          if Map.has_key?(value, :metadata) do
            assert is_map(value.metadata)
          end
          
        is_number(value) ->
          :ok
          
        true ->
          :ok
      end
      
      key_check_end = timestamp_ms()
      key_duration = key_check_end - key_check_start
      
      if key_duration > 10 do
        timestamp_log("Slow key verification: #{inspect(key)} took #{key_duration}ms")
      end
    end)
    
    end_time = timestamp_ms()
    total_duration = end_time - start_time
    
    if total_duration > 100 do
      timestamp_log("SLOW STRUCTURE VERIFICATION: #{total_duration}ms for #{map_size(metrics)} entries")
    end
    
    total_duration
  end
end 