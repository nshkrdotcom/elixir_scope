defmodule ElixirScope.Foundation.Property.FoundationInfrastructurePropertiesTest do
  use ExUnit.Case, async: false  # Foundation operations affect shared state
  use ExUnitProperties
  
  alias ElixirScope.Foundation
  alias ElixirScope.Foundation.{Config, Events, Telemetry, Utils, Error}
  alias ElixirScope.Foundation.Services.{ConfigServer, EventStore, TelemetryService}
  alias ElixirScope.Foundation.TestHelpers
  
  setup do
    # Ensure foundation is available
    :ok = Foundation.initialize()
    
    # Wait for all services to be ready
    TestHelpers.wait_for_service_availability(ConfigServer, 5000)
    TestHelpers.wait_for_service_availability(EventStore, 5000)
    TestHelpers.wait_for_service_availability(TelemetryService, 5000)
    
    :ok
  end
  
  # Generators for test data
  
  defp map_depth_generator(max_depth) do
    sized(fn size ->
      map_depth_generator(min(size, max_depth), 0)
    end)
  end
  
  defp map_depth_generator(max_depth, current_depth) when current_depth >= max_depth do
    one_of([
      string(:alphanumeric),
      integer(),
      float(),
      boolean(),
      atom(:alphanumeric)
    ])
  end
  
  defp map_depth_generator(max_depth, current_depth) do
    one_of([
      string(:alphanumeric),
      integer(),
      float(),
      boolean(),
      atom(:alphanumeric),
      map_of(
        atom(:alphanumeric),
        map_depth_generator(max_depth, current_depth + 1),
        max_length: 3
      )
    ])
  end
  
  defp service_name_generator do
    one_of([
      constant(ConfigServer),
      constant(EventStore),
      constant(TelemetryService)
    ])
  end
  
  defp error_context_generator do
    map_of(atom(:alphanumeric), term(), max_length: 5)
  end
  
  defp startup_sequence_generator do
    # Different permutations of service startup order
    one_of([
      constant([:config, :events, :telemetry]),
      constant([:events, :config, :telemetry]),
      constant([:telemetry, :config, :events]),
      constant([:config, :telemetry, :events]),
      constant([:events, :telemetry, :config]),
      constant([:telemetry, :events, :config])
    ])
  end
  
  # Property Tests
  
  property "Utils.deep_merge(map1, map2) is equivalent to Map.merge for flat maps, but handles nesting" do
    check all map1 <- map_of(atom(:alphanumeric), term(), max_length: 10),
              map2 <- map_of(atom(:alphanumeric), term(), max_length: 10) do
      # For flat maps, deep_merge should equal Map.merge
      merged_deep = Utils.deep_merge(map1, map2)
      merged_regular = Map.merge(map1, map2)
      
      assert merged_deep == merged_regular
      
      # Verify commutativity doesn't hold (map2 wins conflicts)
      merged_reverse = Utils.deep_merge(map2, map1)
      
      # If there are conflicts, results should differ
      if Enum.any?(Map.keys(map1), &Map.has_key?(map2, &1)) do
        # There are conflicts, so order matters
        assert merged_deep != merged_reverse or map1 == map2
      else
        # No conflicts, should be commutative
        assert merged_deep == merged_reverse
      end
    end
  end
  
  property "Utils.deep_merge handles nested maps correctly" do
    check all nested_map1 <- map_depth_generator(3),
              nested_map2 <- map_depth_generator(3) do
      # Should not crash with any input
      result = Utils.deep_merge(nested_map1, nested_map2)
      
      # If both inputs are maps, result should be a map
      if is_map(nested_map1) and is_map(nested_map2) do
        assert is_map(result)
        
        # All keys from both maps should be present
        keys1 = if is_map(nested_map1), do: Map.keys(nested_map1), else: []
        keys2 = if is_map(nested_map2), do: Map.keys(nested_map2), else: []
        all_keys = Enum.uniq(keys1 ++ keys2)
        
        Enum.each(all_keys, fn key ->
          assert Map.has_key?(result, key)
        end)
        
        # Values from map2 should take precedence
        Enum.each(nested_map2, fn {key, value} ->
          if is_map(value) and is_map(Map.get(nested_map1, key)) do
            # Both are maps, should be deep merged
            assert is_map(Map.get(result, key))
          else
            # map2 value should win
            assert Map.get(result, key) == value
          end
        end)
      else
        # If either input is not a map, second argument should win
        assert result == nested_map2
      end
    end
  end
  
  property "Concurrent calls to Utils.generate_id from multiple processes never yield duplicates (on single node)" do
    check all process_count <- integer(5..50),
              ids_per_process <- integer(10..100) do
      # Generate IDs concurrently from multiple processes
      tasks = 
        for _process_id <- 1..process_count do
          Task.async(fn ->
            for _i <- 1..ids_per_process do
              Utils.generate_id()
            end
          end)
        end
      
      # Collect all results
      all_id_lists = Task.await_many(tasks, 10000)
      all_ids = List.flatten(all_id_lists)
      
      # Verify all IDs are integers
      Enum.each(all_ids, fn id ->
        assert is_integer(id)
        assert id > 0
      end)
      
      # Verify no duplicates
      unique_ids = Enum.uniq(all_ids)
      assert length(unique_ids) == length(all_ids),
        "Found duplicates: #{length(all_ids) - length(unique_ids)} out of #{length(all_ids)} IDs"
      
      # Verify reasonable distribution (no obvious patterns)
      if length(all_ids) > 10 do
        # Should have some variance in the IDs
        min_id = Enum.min(all_ids)
        max_id = Enum.max(all_ids)
        assert max_id > min_id
      end
    end
  end
  
  property "Foundation.Supervisor successfully restarts any of its direct children up to max_restarts" do
    check all service_to_restart <- service_name_generator(),
              restart_count <- integer(1..3) do  # Keep low to avoid hitting restart limits
      
      # Ensure service is running
      initial_pid = GenServer.whereis(service_to_restart)
      assert is_pid(initial_pid)
      assert Process.alive?(initial_pid)
      
      # Restart the supervisor multiple times
      final_pid = 
        Enum.reduce(1..restart_count, initial_pid, fn _restart_num, current_pid ->
          # Stop the supervisor
          if Process.alive?(current_pid) do
            GenServer.stop(current_pid, :normal)
          end
          
          # Wait for it to restart
          Process.sleep(100)
          
          # Get new supervisor PID
          new_pid = GenServer.whereis(Foundation.Supervisor)
          assert new_pid != nil
          assert new_pid != current_pid
          
          new_pid
        end)
      
      # Final verification
      assert is_pid(final_pid)
      assert Process.alive?(final_pid)
      assert final_pid != initial_pid
      
      # All services should still be coordinated
      assert Foundation.status() == :running
    end
  end
  
  property "Foundation service coordination maintains consistency under any sequence of start/stop operations" do
    check all operations <- list_of(
      one_of([
        tuple({:stop, service_name_generator()}),
        tuple({:start, service_name_generator()}),
        tuple({:restart, service_name_generator()})
      ]),
      min_length: 3,
      max_length: 10
    ) do
      # Ensure we start in a good state
      :ok = Foundation.initialize()
      TestHelpers.wait_for_all_services_available(5000)
      
      # Execute operations
      Enum.each(operations, fn operation ->
        case operation do
          {:stop, service} ->
            if pid = GenServer.whereis(service) do
              GenServer.stop(pid, :normal)
              Process.sleep(50)  # Allow supervisor to react
            end
            
          {:start, service} ->
            # Supervisor should automatically start, but we can try manual start
            case service do
              ConfigServer -> ConfigServer.initialize()
              EventStore -> EventStore.initialize()
              TelemetryService -> TelemetryService.initialize()
            end
            
          {:restart, service} ->
            if pid = GenServer.whereis(service) do
              GenServer.stop(pid, :normal)
              Process.sleep(50)
              
              # Wait for automatic restart
              TestHelpers.wait_for_service_restart(service, 2000)
            end
        end
        
        # Small delay between operations
        Process.sleep(25)
      end)
      
      # Wait for stabilization
      Process.sleep(200)
      
      # Verify final state is consistent
      # All services should either be running or supervisor should be restarting them
      services = [ConfigServer, EventStore, TelemetryService]
      
      Enum.each(services, fn service ->
        if pid = GenServer.whereis(service) do
          assert Process.alive?(pid)
        end
      end)
      
      # Foundation should be in a consistent state
      status = Foundation.status()
      assert status in [:running, :starting, :degraded]
      
      # Basic operations should work
      {:ok, _} = Config.get()
      {:ok, _} = Telemetry.get_metrics()
    end
  end
  
  property "Foundation error propagation preserves context through any service boundary traversal" do
    check all error_context <- error_context_generator(),
              service_chain <- list_of(service_name_generator(), min_length: 2, max_length: 4) do
      # Create an error with context
      original_error = Error.new(
        :test_propagation_error,
        "Test error for propagation",
        context: error_context,
        correlation_id: Utils.generate_correlation_id()
      )
      
      # Simulate error propagation through service chain
      final_error = 
        Enum.reduce(service_chain, original_error, fn service, current_error ->
          # Each service adds its own context while preserving original
          service_context = %{
            service: service,
            timestamp: System.monotonic_time(),
            operation: :error_handling
          }
          
          # Wrap the error (simulating service boundary crossing)
          {:error, wrapped_error} = Error.wrap_error(
            {:error, current_error},
            :service_boundary_error,
            "Error crossed #{service} boundary",
            context: service_context
          )
          
          wrapped_error
        end)
      
      # Verify original context is preserved
      assert final_error.correlation_id == original_error.correlation_id
      
      # Original context should be preserved in the final error
      Enum.each(error_context, fn {key, value} ->
        assert Map.get(final_error.context, key) == value,
          "Original context key #{inspect(key)} not preserved"
      end)
      
      # Wrapper information should be present
      assert Map.has_key?(final_error.context, :wrapped_by)
      assert Map.has_key?(final_error.context, :wrapper_message)
      
      # Should have service context from at least one service
      service_contexts = 
        Enum.filter(service_chain, fn service ->
          Map.get(final_error.context, :service) == service
        end)
      
      assert length(service_contexts) > 0
    end
  end
  
  property "Foundation telemetry collection overhead remains bounded regardless of operation volume" do
    check all operation_count <- integer(100..1000) do
      # Measure baseline performance without telemetry
      TelemetryService.reset_metrics()
      
      baseline_start = System.monotonic_time(:microsecond)
      
      # Perform operations without telemetry
      for _i <- 1..operation_count do
        _id = Utils.generate_id()
        _correlation_id = Utils.generate_correlation_id()
      end
      
      baseline_end = System.monotonic_time(:microsecond)
      baseline_duration = baseline_end - baseline_start
      
      # Measure performance with telemetry
      telemetry_start = System.monotonic_time(:microsecond)
      
      # Perform same operations with telemetry
      for _i <- 1..operation_count do
        _id = Utils.generate_id()
        _correlation_id = Utils.generate_correlation_id()
        
        # Add telemetry collection
        Telemetry.emit_counter([:foundation, :operations], %{operation: :id_generation}, 1)
      end
      
      telemetry_end = System.monotonic_time(:microsecond)
      telemetry_duration = telemetry_end - telemetry_start
      
      # Calculate overhead
      overhead = telemetry_duration - baseline_duration
      overhead_percentage = (overhead / baseline_duration) * 100
      
      # Overhead should be reasonable (less than 100% in most cases)
      assert overhead_percentage < 200,
        "Telemetry overhead too high: #{Float.round(overhead_percentage, 2)}% " <>
        "(#{overhead}μs overhead for #{operation_count} operations)"
      
      # Verify telemetry was actually collected
      {:ok, metrics} = Telemetry.get_metrics()
      operations_count = get_in(metrics, [:foundation, :operations])
      assert operations_count == operation_count
    end
  end
  
  property "Foundation resource cleanup is complete after any shutdown sequence" do
    check all shutdown_sequence <- list_of(service_name_generator(), min_length: 1, max_length: 3) do
      # Get initial resource state
      initial_processes = length(Process.list())
      initial_ets_tables = length(:ets.all())
      
      # Ensure foundation is running
      :ok = Foundation.initialize()
      TestHelpers.wait_for_all_services_available(3000)
      
      # Perform shutdown sequence
      Enum.each(shutdown_sequence, fn service ->
        if pid = GenServer.whereis(service) do
          # Graceful shutdown
          try do
            GenServer.stop(pid, :normal, 1000)
          catch
            :exit, _ -> :ok  # Already stopped
          end
        end
        
        Process.sleep(50)
      end)
      
      # Wait for cleanup
      Process.sleep(500)
      
      # Check resource usage
      final_processes = length(Process.list())
      final_ets_tables = length(:ets.all())
      
      # Resource usage should not have grown significantly
      process_growth = final_processes - initial_processes
      ets_growth = final_ets_tables - initial_ets_tables
      
      # Some growth is expected due to test processes, but should be bounded
      assert process_growth < 50, 
        "Too many processes leaked: #{process_growth} (#{initial_processes} -> #{final_processes})"
      
      assert ets_growth < 10,
        "Too many ETS tables leaked: #{ets_growth} (#{initial_ets_tables} -> #{final_ets_tables})"
      
      # Restart foundation to verify clean startup
      :ok = Foundation.initialize()
      assert Foundation.status() in [:running, :starting]
    end
  end
  
  property "Foundation state transitions are atomic and never leave services in inconsistent states" do
    check all transition_count <- integer(3..10) do
      # Start in known good state
      :ok = Foundation.initialize()
      TestHelpers.wait_for_all_services_available(3000)
      
      # Perform multiple rapid state transitions
      for _i <- 1..transition_count do
        # Trigger state transition by updating config
        config_path = [:dev, :debug_mode]
        current_value = case Config.get(config_path) do
          {:ok, value} -> value
          {:error, _} -> false
        end
        
        new_value = not current_value
        
        # This should trigger events and telemetry updates
        :ok = Config.update(config_path, new_value)
        
        # Small delay to allow propagation
        Process.sleep(10)
        
        # Verify state is consistent across all services
        # Config should reflect the update
        {:ok, updated_value} = Config.get(config_path)
        assert updated_value == new_value
        
        # EventStore should be responsive
        assert EventStore.available?()
        {:ok, _events} = EventStore.query(%{})
        
        # TelemetryService should be responsive
        assert TelemetryService.available?()
        {:ok, _metrics} = Telemetry.get_metrics()
      end
      
      # Final consistency check
      assert Foundation.status() == :running
      
      # All services should be in consistent, responsive state
      assert ConfigServer.available?()
      assert EventStore.available?()  
      assert TelemetryService.available?()
    end
  end
  
  property "Foundation inter-service dependencies resolve correctly in any startup order" do
    check all startup_order <- startup_sequence_generator() do
      # Stop all services
      [ConfigServer, EventStore, TelemetryService]
      |> Enum.each(fn service ->
        if pid = GenServer.whereis(service) do
          GenServer.stop(pid, :kill)
        end
      end)
      
      Process.sleep(100)
      
      # Start services in specified order
      service_map = %{
        config: ConfigServer,
        events: EventStore,
        telemetry: TelemetryService
      }
      
      Enum.each(startup_order, fn service_key ->
        service = Map.get(service_map, service_key)
        
        case service do
          ConfigServer -> ConfigServer.initialize()
          EventStore -> EventStore.initialize()
          TelemetryService -> TelemetryService.initialize()
        end
        
        # Wait a bit for startup
        Process.sleep(100)
      end)
      
      # Wait for full initialization
      Process.sleep(500)
      
      # Verify all services are functional regardless of startup order
      assert ConfigServer.available?()
      assert EventStore.available?()
      assert TelemetryService.available?()
      
      # Verify they can interact with each other
      # Config update should trigger event and telemetry
      correlation_id = Utils.generate_correlation_id()
      :ok = Config.update([:dev, :debug_mode], true)
      
      # Should be able to store events
      {:ok, event} = Events.new_event(:test_startup_order, %{order: startup_order}, correlation_id: correlation_id)
      {:ok, _event_id} = EventStore.store(event)
      
      # Should be able to emit telemetry
      :ok = Telemetry.emit_counter([:foundation, :startup_test], %{order: startup_order}, 1)
      
      # All should be queryable
      {:ok, _config} = Config.get()
      {:ok, events} = EventStore.get_by_correlation(correlation_id)
      assert length(events) > 0
      
      {:ok, metrics} = Telemetry.get_metrics()
      startup_count = get_in(metrics, [:foundation, :startup_test])
      assert startup_count >= 1
    end
  end
  
  property "Foundation health checks accurately reflect actual service states" do
    check all services_to_test <- list_of(service_name_generator(), min_length: 1, max_length: 3) do
      # Ensure all services are running
      :ok = Foundation.initialize()
      TestHelpers.wait_for_all_services_available(3000)
      
      initial_status = Foundation.status()
      assert initial_status == :running
      
      # Stop some services and verify health checks reflect this
      stopped_services = Enum.uniq(services_to_test)
      
      Enum.each(stopped_services, fn service ->
        if pid = GenServer.whereis(service) do
          GenServer.stop(pid, :kill)
        end
      end)
      
      # Wait for health checks to detect the changes
      Process.sleep(200)
      
      # Status should reflect degraded state if services are down
      degraded_status = Foundation.status()
      
      if length(stopped_services) > 0 do
        assert degraded_status in [:degraded, :starting]
      end
      
      # Wait for supervisor to restart services
      Process.sleep(1000)
      
      # Health should recover
      final_status = Foundation.status()
      assert final_status in [:running, :starting]
      
      # Individual service health checks should be accurate
      Enum.each([ConfigServer, EventStore, TelemetryService], fn service ->
        health_status = case service do
          ConfigServer -> ConfigServer.available?()
          EventStore -> EventStore.available?()
          TelemetryService -> TelemetryService.available?()
        end
        
        # If service is running, health check should return true
        if GenServer.whereis(service) do
          assert health_status == true
        end
      end)
    end
  end
  
  # Helper functions remain the same as they don't need property testing
end 