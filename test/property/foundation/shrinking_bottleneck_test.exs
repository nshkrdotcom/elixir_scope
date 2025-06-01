defmodule ElixirScope.Foundation.Property.ShrinkingBottleneckTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  
  alias ElixirScope.Foundation.Services.TelemetryService
  
  # Timing utilities
  defp timestamp_ms, do: System.monotonic_time(:millisecond)
  
  defp timestamp_log(message) do
    IO.puts("[#{DateTime.utc_now() |> DateTime.to_string()}] #{message}")
    timestamp_ms()
  end

  setup do
    # Ensure service is running
    unless Process.whereis(TelemetryService) do
      TelemetryService.start_link([])
    end
    :ok
  end

  # Test 1: Trigger actual shrinking with simple failure
  @tag :intentional_failure
  property "SHRINKING TEST: Simple failure to measure framework overhead" do
    timestamp_log("=== STARTING SIMPLE SHRINKING TEST ===")
    
    check all value <- StreamData.integer(1..100),
              max_runs: 10 do
      
      test_start = timestamp_ms()
      timestamp_log("Testing value: #{value} (expecting failure on values > 50)")
      
      # Intentional failure to trigger shrinking
      if value > 50 do
        timestamp_log("INTENTIONAL FAILURE: value #{value} > 50 - this will trigger shrinking")
        timestamp_log("Run duration before failure: #{timestamp_ms() - test_start}ms")
        assert false, "Intentional failure to measure shrinking overhead (value=#{value})"
      end
      
      test_end = timestamp_ms()
      test_duration = test_end - test_start
      timestamp_log("Success run duration: #{test_duration}ms")
    end
  end

  # Test 2: Trigger shrinking with complex generators (like original tests)
  property "SHRINKING TEST: Complex generators to measure overhead" do
    start_time = timestamp_log("=== STARTING COMPLEX SHRINKING TEST ===")
    
    # Use the same generator structure as the slow original tests
    operations_generator = StreamData.list_of(
      StreamData.one_of([
        StreamData.tuple({
          StreamData.constant(:counter),
          StreamData.list_of(StreamData.atom(:alphanumeric), min_length: 1, max_length: 3),
          StreamData.integer(1..10),
          StreamData.constant(%{})
        }),
        StreamData.tuple({
          StreamData.constant(:gauge),
          StreamData.list_of(StreamData.atom(:alphanumeric), min_length: 1, max_length: 3),
          StreamData.float(min: 0.0, max: 100.0),
          StreamData.constant(%{})
        })
      ]),
      min_length: 3,
      max_length: 8  # This should trigger complex shrinking
    )
    
    check all operations <- operations_generator,
              max_runs: 3 do  # Very limited to avoid excessive shrinking
      
      run_start = timestamp_ms()
      timestamp_log("Testing #{length(operations)} operations")
      
      # Execute the operations (fast, as we proved above)
      Enum.each(operations, fn {type, path, value, metadata} ->
        case type do
          :counter -> TelemetryService.emit_counter(path, metadata)
          :gauge -> TelemetryService.emit_gauge(path, value, metadata)
        end
      end)
      
      # Get metrics (also fast)
      {:ok, metrics} = TelemetryService.get_metrics()
      
      # Intentional failure to trigger complex shrinking
      if length(operations) > 5 do
        timestamp_log("INTENTIONAL FAILURE: #{length(operations)} operations > 5 - triggering complex shrinking")
        run_end = timestamp_ms()
        timestamp_log("Run duration before failure: #{run_end - run_start}ms")
        timestamp_log("Metrics collected: #{map_size(metrics)} entries")
        assert false, "Intentional failure with complex generators (ops=#{length(operations)})"
      end
      
      run_end = timestamp_ms()
      timestamp_log("Success run duration: #{run_end - run_start}ms")
    end
    
    end_time = timestamp_ms()
    timestamp_log("=== COMPLEX SHRINKING TEST COMPLETE: #{end_time - start_time}ms ===")
  end

  # Test 3: Measure the overhead of service restarts during failures
  @tag :intentional_failure
  property "SHRINKING TEST: Service restart overhead during failures" do
    timestamp_log("=== STARTING SERVICE RESTART OVERHEAD TEST ===")
    
    check all restart_trigger <- StreamData.boolean(),
              max_runs: 5 do
      
      test_start = timestamp_ms()
      
      if restart_trigger do
        timestamp_log("TRIGGERING SERVICE RESTART SCENARIO")
        
        # Stop and restart service to simulate test isolation overhead
        restart_start = timestamp_ms()
        if Process.whereis(TelemetryService) do
          GenServer.stop(TelemetryService, :normal, 1000)
        end
        
        case TelemetryService.start_link([]) do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
        end
        restart_end = timestamp_ms()
        
        timestamp_log("Service restart took: #{restart_end - restart_start}ms")
        
        # Intentional failure to trigger shrinking in the expensive case
        timestamp_log("INTENTIONAL FAILURE: after service restart")
        test_end = timestamp_ms()
        timestamp_log("Run duration with restart: #{test_end - test_start}ms")
        assert false, "Intentional failure after service restart"
      end
      
      # Success case - minimal work
      test_end = timestamp_ms()
      timestamp_log("Success run duration: #{test_end - test_start}ms")
    end
  end

  # Test 4: Test with exact same structure as original failing test
  property "SHRINKING TEST: Replicate original telemetry test structure" do
    start_time = timestamp_log("=== STARTING ORIGINAL STRUCTURE REPLICATION ===")
    
    # Exact same generator as the original slow test
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
          StreamData.constant(0.0), 
          StreamData.constant(%{})
        }),
        StreamData.tuple({
          StreamData.constant(:counter), 
          StreamData.constant([:foundation, :config_updates]), 
          StreamData.constant(1), 
          StreamData.constant(%{})
        })
      ]),
      min_length: 3,
      max_length: 6
    )
    
    check all operations <- mixed_operation_sequence_generator,
              max_runs: 2 do
      
      run_start = timestamp_ms()
      timestamp_log("Replicating original test with #{length(operations)} operations")
      
      # Execute operations exactly like original
      Enum.each(operations, fn {type, path, value, metadata} ->
        case type do
          :counter -> TelemetryService.emit_counter(path, metadata)
          :gauge -> TelemetryService.emit_gauge(path, value, metadata)
        end
      end)
      
      # Get metrics
      {:ok, metrics} = TelemetryService.get_metrics()
      
      # Verify structure like original (this might be slow?)
      structure_start = timestamp_ms()
      verify_metrics_structure(metrics)
      structure_end = timestamp_ms()
      timestamp_log("Structure verification took: #{structure_end - structure_start}ms")
      
      # Intentional failure to trigger exact same shrinking as original
      if length(operations) >= 4 do
        timestamp_log("INTENTIONAL FAILURE: replicating original failure condition")
        run_end = timestamp_ms()
        timestamp_log("Run duration before failure: #{run_end - run_start}ms")
        assert false, "Replicating original test failure pattern"
      end
      
      run_end = timestamp_ms()
      timestamp_log("Success run duration: #{run_end - run_start}ms")
    end
    
    end_time = timestamp_ms()
    timestamp_log("=== ORIGINAL STRUCTURE REPLICATION COMPLETE: #{end_time - start_time}ms ===")
  end

  # Helper function that might be causing slowdowns
  defp verify_metrics_structure(metrics) when is_map(metrics) do
    structure_start = timestamp_ms()
    
    Enum.each(metrics, fn {key, value} ->
      key_start = timestamp_ms()
      
      # Check if this verification is slow
      cond do
        is_map(value) ->
          # Deep inspection might be slow
          if Map.has_key?(value, :measurements) do
            assert is_map(value.measurements)
            # Check nested structure
            Enum.each(value.measurements, fn {k, v} ->
              assert is_atom(k) or is_binary(k)
              assert is_number(v) or is_map(v)
            end)
          end
          if Map.has_key?(value, :metadata) do
            assert is_map(value.metadata)
          end
        
        is_number(value) -> :ok
        true -> :ok
      end
      
      key_end = timestamp_ms()
      if key_end - key_start > 5 do
        timestamp_log("SLOW key verification: #{inspect(key)} took #{key_end - key_start}ms")
      end
    end)
    
    structure_end = timestamp_ms()
    total_time = structure_end - structure_start
    
    if total_time > 50 do
      timestamp_log("SLOW STRUCTURE VERIFICATION: #{total_time}ms for #{map_size(metrics)} entries")
    end
    
    total_time
  end
end 