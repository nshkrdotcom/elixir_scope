defmodule ElixirScope.Foundation.Property.FinalBottleneckAnalysisTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  
  @moduletag :slow  # Property tests are inherently slow
  
  alias ElixirScope.Foundation.{Telemetry}
  alias ElixirScope.Foundation.Services.TelemetryService
  
  # Timing utilities
  defp timestamp_ms, do: System.monotonic_time(:millisecond)
  
  defp timestamp_log(message) do
    IO.puts("[#{DateTime.utc_now() |> DateTime.to_string()}] #{message}")
    timestamp_ms()
  end

  setup do
    # Ensure service is running without restart issues
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    :ok
  end

  # Test the EXACT failing pattern from original tests
  property "FINAL TEST: Exact reproduction of original 32-second delay" do
    start_time = timestamp_log("=== STARTING EXACT REPRODUCTION ===")
    
    # This is the EXACT generator and pattern from the original failing test
    mixed_operation_sequence_generator = StreamData.list_of(
      StreamData.one_of([
        StreamData.tuple({
          StreamData.constant(:gauge), 
          StreamData.constant([:A]), 
          StreamData.constant(1000.0), 
          StreamData.constant(%{})
        }),
        StreamData.tuple({
          StreamData.constant(:gauge), 
          StreamData.constant([:foundation, :config_updates]), 
          StreamData.constant(0), 
          StreamData.constant(%{})
        }),
        StreamData.tuple({
          StreamData.constant(:counter), 
          StreamData.constant([:foundation, :config_updates]), 
          StreamData.constant(1), 
          StreamData.constant(%{})
        }),
        StreamData.tuple({
          StreamData.constant(:gauge), 
          StreamData.constant([:foundation, :config_updates]), 
          StreamData.constant(0), 
          StreamData.constant(%{})
        }),
        StreamData.tuple({
          StreamData.constant(:counter), 
          StreamData.constant([:foundation, :config_updates]), 
          StreamData.constant(1), 
          StreamData.constant(%{})
        })
      ]),
      min_length: 5,
      max_length: 5
    )
    
    check all operations <- mixed_operation_sequence_generator,
              max_runs: 1 do  # Just one run to avoid endless shrinking
      
      run_start = timestamp_ms()
      timestamp_log("=== REPRODUCING ORIGINAL TEST EXECUTION ===")
      timestamp_log("Operations: #{inspect(operations)}")
      
      # Execute EXACTLY like the original failing test
      exec_start = timestamp_ms()
      Enum.each(operations, fn operation ->
        case operation do
          {:counter, path, increment, metadata} ->
            # EXACT original call that was failing
            :ok = Telemetry.emit_counter(path, Map.put(metadata, :increment, increment))
          {:gauge, path, value, metadata} ->
            # EXACT original call that was failing  
            :ok = Telemetry.emit_gauge(path, value, metadata)
        end
      end)
      exec_end = timestamp_ms()
      timestamp_log("Operations execution: #{exec_end - exec_start}ms")
      
      # Get metrics EXACTLY like original
      metrics_start = timestamp_ms()
      {:ok, final_metrics} = Telemetry.get_metrics()
      metrics_end = timestamp_ms()
      timestamp_log("Get metrics: #{metrics_end - metrics_start}ms")
      
      # Do EXACT verification that was slow in original
      verify_start = timestamp_ms()
      timestamp_log("Starting EXACT original verification...")
      
      # This is the EXACT verification from the original slow test
      verify_metrics_structure_exact(final_metrics)
      
      verify_end = timestamp_ms()
      verify_duration = verify_end - verify_start
      timestamp_log("EXACT verification: #{verify_duration}ms")
      
      # Check if this is the slow part
      if verify_duration > 1000 do
        timestamp_log("*** FOUND THE BOTTLENECK: Verification took #{verify_duration}ms ***")
      end
      
      run_end = timestamp_ms()
      total_duration = run_end - run_start
      timestamp_log("Total run: #{total_duration}ms")
      
      # Let's intentionally fail to see shrinking behavior
      if length(operations) >= 5 do
        timestamp_log("INTENTIONAL FAILURE: This should trigger the 32-second shrinking delay")
        failure_time = timestamp_ms()
        assert false, "Triggering original failure pattern at #{failure_time}ms"
      end
    end
    
    end_time = timestamp_ms()
    timestamp_log("=== EXACT REPRODUCTION COMPLETE: #{end_time - start_time}ms ===")
  end

  # Test just the verification function in isolation
  test "VERIFICATION ISOLATION: Test the slow verification function alone" do
    start_time = timestamp_log("=== TESTING VERIFICATION IN ISOLATION ===")
    
    # Set up some metrics like the original failing tests
    Telemetry.emit_gauge([:A], 1000.0, %{})
    Telemetry.emit_gauge([:foundation, :config_updates], 0, %{})
    Telemetry.emit_counter([:foundation, :config_updates], %{increment: 1})
    
    {:ok, metrics} = Telemetry.get_metrics()
    timestamp_log("Metrics to verify: #{inspect(metrics, limit: :infinity)}")
    
    # Test the verification function that might be slow
    verification_times = for i <- 1..10 do
      verify_start = timestamp_ms()
      verify_metrics_structure_exact(metrics)
      verify_end = timestamp_ms()
      duration = verify_end - verify_start
      timestamp_log("Verification attempt #{i}: #{duration}ms")
      duration
    end
    
    avg_time = Enum.sum(verification_times) / length(verification_times)
    max_time = Enum.max(verification_times)
    
    timestamp_log("Average verification time: #{avg_time}ms")
    timestamp_log("Maximum verification time: #{max_time}ms")
    
    if max_time > 100 do
      timestamp_log("*** VERIFICATION IS THE BOTTLENECK: #{max_time}ms ***")
    end
    
    end_time = timestamp_ms()
    timestamp_log("=== VERIFICATION ISOLATION COMPLETE: #{end_time - start_time}ms ===")
  end

  # Test to find what's different between fast and slow metrics
  test "METRICS STRUCTURE: Compare fast vs slow metrics patterns" do
    start_time = timestamp_log("=== ANALYZING METRICS STRUCTURE DIFFERENCES ===")
    
    # Create "fast" metrics (like our performance tests)
    TelemetryService.emit_counter([:fast, :test], %{})
    TelemetryService.emit_gauge([:fast, :gauge], 42.0, %{})
    {:ok, fast_metrics} = TelemetryService.get_metrics()
    timestamp_log("Fast metrics structure: #{inspect(fast_metrics, limit: :infinity)}")
    
    # Create "slow" metrics (like original failing tests) 
    Telemetry.emit_counter([:foundation, :config_updates], %{increment: 1})
    Telemetry.emit_gauge([:A], 1000.0, %{})
    {:ok, slow_metrics} = Telemetry.get_metrics()
    timestamp_log("Slow metrics structure: #{inspect(slow_metrics, limit: :infinity)}")
    
    # Compare the structures
    timestamp_log("=== STRUCTURAL ANALYSIS ===")
    timestamp_log("Fast metrics keys: #{inspect(Map.keys(fast_metrics))}")
    timestamp_log("Slow metrics keys: #{inspect(Map.keys(slow_metrics))}")
    
    # Check for problematic key types
    Enum.each(slow_metrics, fn {key, value} ->
      key_type = cond do
        is_atom(key) -> :atom
        is_binary(key) -> :binary
        is_integer(key) -> :integer
        is_list(key) -> :list
        true -> :other
      end
      
      value_complexity = if is_map(value), do: map_size(value), else: 1
      
      timestamp_log("Key: #{inspect(key)} (#{key_type}), Value complexity: #{value_complexity}")
      
      if key_type == :other do
        timestamp_log("*** PROBLEMATIC KEY TYPE FOUND: #{inspect(key)} ***")
      end
    end)
    
    end_time = timestamp_ms()
    timestamp_log("=== METRICS STRUCTURE ANALYSIS COMPLETE: #{end_time - start_time}ms ===")
  end

  # The EXACT verification function from original failing tests
  defp verify_metrics_structure_exact(metrics) when is_map(metrics) do
    verify_start = timestamp_ms()
    
    Enum.each(metrics, fn {key, value} ->
      key_start = timestamp_ms()
      
      # This was the failing assertion in original tests
      assert is_atom(key), "Metric key should be atom, got #{inspect(key)}"
      
      # Check value types that were causing failures
      case value do
        v when is_number(v) -> 
          :ok
        v when is_map(v) -> 
          # This recursive call might be the issue
          verify_metrics_structure_exact(v)
        v when is_boolean(v) -> 
          :ok
        v when is_binary(v) -> 
          :ok
        v when is_atom(v) -> 
          :ok
        other -> 
          flunk("Invalid metric value type: #{inspect(other)}")
      end
      
      key_end = timestamp_ms()
      key_duration = key_end - key_start
      
      if key_duration > 5 do
        timestamp_log("SLOW KEY: #{inspect(key)} took #{key_duration}ms")
      end
    end)
    
    verify_end = timestamp_ms()
    total_time = verify_end - verify_start
    
    if total_time > 10 do
      timestamp_log("SLOW VERIFICATION: #{total_time}ms for #{map_size(metrics)} keys")
    end
  end
end 