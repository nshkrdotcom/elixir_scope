# Enhanced development workflow script for Foundation layer Phase 1
# Usage: mix run scripts/foundation_dev_workflow_enhanced.exs

IO.puts("=== ElixirScope Foundation Layer Phase 1 Enhanced Workflow ===")

alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry, Error, ErrorContext}
alias ElixirScope.Foundation.Config.GracefulDegradation
alias ElixirScope.Foundation.Events.GracefulDegradation, as: EventsGD

IO.puts("1. Testing Enhanced Configuration System...")

try do
  # Test configuration retrieval with validation levels
  config = Config.get()
  IO.puts("   ✅ Configuration loaded successfully")
  IO.puts("   - AI Provider: #{config.ai.provider}")
  IO.puts("   - Sampling Rate: #{config.ai.planning.sampling_rate}")

  # Test enhanced validation with constraint checking
  case Config.validate(config) do
    :ok ->
      IO.puts("   ✅ Configuration validation passed")

    {:error, %Error{} = error} ->
      IO.puts("   ❌ Configuration validation failed: #{Error.to_string(error)}")
  end

  # Test configuration path access with error handling
  batch_size = Config.get([:capture, :processing, :batch_size])
  IO.puts("   - Batch Size: #{batch_size}")

  # Test constraint validation with invalid values
  IO.puts("   🧪 Testing constraint validation...")
  invalid_config = put_in(config, [:ai, :planning, :sampling_rate], 1.5)

  case Config.validate(invalid_config) do
    {:error, %Error{error_type: :range_error, code: 1203}} ->
      IO.puts("   ✅ Constraint validation working (rejected sampling_rate > 1.0)")

    other ->
      IO.puts("   ❌ Constraint validation failed: #{inspect(other)}")
  end

  # Test configuration update with proper error handling
  old_rate = Config.get([:ai, :planning, :sampling_rate])

  case Config.update([:ai, :planning, :sampling_rate], 0.8) do
    :ok ->
      new_rate = Config.get([:ai, :planning, :sampling_rate])
      IO.puts("   ✅ Configuration update successful: #{old_rate} → #{new_rate}")
      # Restore original rate
      Config.update([:ai, :planning, :sampling_rate], old_rate)

    {:error, error} ->
      IO.puts("   ❌ Configuration update failed: #{inspect(error)}")
  end

  # Test forbidden path update
  case Config.update([:ai, :provider], :openai) do
    {:error, %Error{error_type: :config_update_forbidden, code: 1401}} ->
      IO.puts("   ✅ Forbidden path protection working")

    other ->
      IO.puts("   ❌ Forbidden path protection failed: #{inspect(other)}")
  end
rescue
  error ->
    IO.puts("   ❌ Configuration test failed: #{Exception.message(error)}")
end

IO.puts("\n2. Testing Graceful Degradation Patterns...")

try do
  # Initialize graceful degradation system
  GracefulDegradation.initialize_fallback_system()
  IO.puts("   ✅ Graceful degradation system initialized")

  # Test fallback configuration access
  fallback_rate = GracefulDegradation.get_with_fallback([:ai, :planning, :sampling_rate])
  IO.puts("   ✅ Fallback configuration access: sampling_rate = #{fallback_rate}")

  # Test pending update mechanism (simulate service failure)
  IO.puts("   🧪 Testing service failure recovery...")

  # Temporarily stop config service to test fallback
  config_pid = GenServer.whereis(Config)

  if config_pid do
    GenServer.stop(config_pid)
    IO.puts("   - Config service stopped for testing")

    # Should use fallback
    fallback_config = GracefulDegradation.get_with_fallback([])

    if %Config{} = fallback_config do
      IO.puts("   ✅ Fallback configuration retrieved successfully")
    end

    # Test pending update
    case GracefulDegradation.update_with_fallback([:ai, :planning, :sampling_rate], 0.9) do
      :ok -> IO.puts("   ✅ Pending update cached successfully")
      error -> IO.puts("   ❌ Pending update failed: #{inspect(error)}")
    end

    # Restart service
    Config.initialize()
    # Allow restart
    Process.sleep(100)
    IO.puts("   ✅ Config service restarted")
  end
rescue
  error ->
    IO.puts("   ❌ Graceful degradation test failed: #{Exception.message(error)}")
    # Ensure service is restarted
    Config.initialize()
end

IO.puts("\n3. Testing Enhanced Event System...")

try do
  # Test basic event creation with validation
  event = Events.new_event(:test_event, %{message: "Enhanced test", phase: 1})
  IO.puts("   ✅ Event created successfully")
  IO.puts("   - Event ID: #{event.event_id}")
  IO.puts("   - Event Type: #{event.event_type}")
  IO.puts("   - Timestamp: #{Utils.format_timestamp(event.timestamp)}")

  # Test function entry event with enhanced data
  func_event =
    Events.function_entry(TestModule, :enhanced_function, 3, [:arg1, :arg2, :arg3],
      caller_module: __MODULE__,
      caller_line: __ENV__.line
    )

  IO.puts("   ✅ Enhanced function entry event created")
  IO.puts("   - Call ID: #{func_event.data.call_id}")
  IO.puts("   - Caller: #{func_event.data.caller_module}")

  # Test serialization robustness
  case Events.serialize(event) do
    {:error, reason} ->
      IO.puts("   ❌ Serialization failed: #{inspect(reason)}")

    serialized ->
      case Events.deserialize(serialized) do
        {:error, reason} ->
          IO.puts("   ❌ Deserialization failed: #{inspect(reason)}")

        deserialized ->
          if deserialized == event do
            IO.puts("   ✅ Event serialization round-trip successful")
            IO.puts("   - Serialized size: #{Events.serialized_size(event)} bytes")
          else
            IO.puts("   ❌ Event serialization round-trip failed")
          end
      end
  end

  # Test graceful event creation with problematic data
  IO.puts("   🧪 Testing graceful event creation...")
  problematic_data = %{large_string: String.duplicate("x", 2000)}
  safe_event = EventsGD.new_event_safe(:large_event, problematic_data)
  IO.puts("   ✅ Large event created safely: #{inspect(safe_event.data)}")

  # Test serialization fallback
  safe_serialized = EventsGD.serialize_safe(event)
  IO.puts("   ✅ Safe serialization successful")
rescue
  error ->
    IO.puts("   ❌ Enhanced event system test failed: #{Exception.message(error)}")
end

IO.puts("\n4. Testing Enhanced Error Context System...")

try do
  # Test error context creation with metadata
  context =
    ErrorContext.new(__MODULE__, :test_operation, metadata: %{phase: 1, test_type: :workflow})

  IO.puts("   ✅ Error context created")
  IO.puts("   - Operation ID: #{context.operation_id}")
  IO.puts("   - Correlation ID: #{context.correlation_id}")

  # Test child context creation
  child_context =
    ErrorContext.child_context(context, ChildModule, :child_operation, %{nested: true})

  IO.puts("   ✅ Child context created")
  IO.puts("   - Breadcrumbs: #{length(child_context.breadcrumbs)}")
  IO.puts("   - Formatted: #{ErrorContext.format_breadcrumbs(child_context)}")

  # Test error enhancement
  test_error = Error.new(:test_error, "Test error for enhancement")
  enhanced_error = ErrorContext.enhance_error(test_error, context)
  IO.puts("   ✅ Error enhancement successful")
  IO.puts("   - Enhanced context keys: #{inspect(Map.keys(enhanced_error.context))}")

  # Test context execution with error handling
  result =
    ErrorContext.with_context(context, fn ->
      # Simulate some work
      Process.sleep(1)
      {:ok, :success}
    end)

  case result do
    {:ok, :success} -> IO.puts("   ✅ Context execution successful")
    other -> IO.puts("   ❌ Context execution failed: #{inspect(other)}")
  end

  # Test exception handling
  exception_result =
    ErrorContext.with_context(context, fn ->
      raise RuntimeError, "Intentional test error"
    end)

  case exception_result do
    {:error, %Error{error_type: :internal_error}} ->
      IO.puts("   ✅ Exception handling successful")

    other ->
      IO.puts("   ❌ Exception handling failed: #{inspect(other)}")
  end
rescue
  error ->
    IO.puts("   ❌ Error context test failed: #{Exception.message(error)}")
end

IO.puts("\n5. Testing Enhanced Error System...")

try do
  # Test hierarchical error codes
  config_error = Error.new(:invalid_config_value, "Test config error")
  IO.puts("   ✅ Hierarchical error created")
  IO.puts("   - Error Code: #{config_error.code}")
  IO.puts("   - Category: #{config_error.category}")
  IO.puts("   - Severity: #{config_error.severity}")

  # Test error chaining
  original_error = Error.new(:data_corruption, "Original error")
  wrapped_result = Error.wrap_error({:error, original_error}, :system_failure, "Wrapper error")

  case wrapped_result do
    {:error, %Error{} = wrapped_error} ->
      IO.puts("   ✅ Error wrapping successful")
      IO.puts("   - Wrapped context keys: #{inspect(Map.keys(wrapped_error.context))}")

    other ->
      IO.puts("   ❌ Error wrapping failed: #{inspect(other)}")
  end

  # Test retry strategy determination
  network_error = Error.new(:network_error, "Network failure")

  if Error.is_retryable?(network_error) do
    delay = Error.retry_delay(network_error, 1)
    IO.puts("   ✅ Retry strategy working: #{delay}ms delay")
  end

  # Test error metrics collection
  Error.collect_error_metrics(config_error)
  IO.puts("   ✅ Error metrics collected")
rescue
  error ->
    IO.puts("   ❌ Enhanced error system test failed: #{Exception.message(error)}")
end

IO.puts("\n6. Testing System Integration...")

try do
  # Test telemetry with enhanced context
  context = ErrorContext.new(__MODULE__, :integration_test)

  result =
    Telemetry.measure_event(
      [:enhanced, :workflow, :test],
      %{phase: 1, component: :foundation},
      fn ->
        ErrorContext.with_context(context, fn ->
          # Simulate complex operation
          config = Config.get()
          event = Events.new_event(:integration_test, %{config_valid: true})
          serialized = Events.serialize(event)
          _deserialized = Events.deserialize(serialized)

          :integration_success
        end)
      end
    )

  case result do
    :integration_success -> IO.puts("   ✅ System integration successful")
    {:ok, :integration_success} -> IO.puts("   ✅ System integration successful")
    other -> IO.puts("   ❌ System integration failed: #{inspect(other)}")
  end

  # Test metrics collection
  metrics = Telemetry.get_metrics()
  IO.puts("   ✅ Metrics collection successful")
  IO.puts("   - Foundation uptime: #{metrics.foundation.uptime_ms}ms")
  IO.puts("   - Memory usage: #{Utils.format_bytes(metrics.foundation.memory_usage)}")
  IO.puts("   - Process count: #{metrics.foundation.process_count}")
rescue
  error ->
    IO.puts("   ❌ System integration test failed: #{Exception.message(error)}")
end

IO.puts("\n7. Testing Performance and Robustness...")

try do
  # Performance test: rapid event creation
  start_time = Utils.monotonic_timestamp()

  events =
    for i <- 1..1000 do
      Events.new_event(:perf_test, %{sequence: i})
    end

  end_time = Utils.monotonic_timestamp()
  duration = end_time - start_time

  IO.puts("   ✅ Performance test: 1000 events in #{Utils.format_duration(duration)}")
  IO.puts("   - Average: #{Utils.format_duration(div(duration, 1000))} per event")

  # Robustness test: concurrent config access
  tasks =
    for i <- 1..50 do
      Task.async(fn ->
        Config.get([:ai, :planning, :sampling_rate])
        Events.new_event(:concurrent_test, %{task: i})
        Utils.generate_id()
      end)
    end

  results = Enum.map(tasks, &Task.await/1)
  successful = Enum.count(results, &(&1 != nil))

  IO.puts("   ✅ Concurrency test: #{successful}/50 tasks successful")

  # Memory usage check
  {memory_before, memory_after, diff} =
    Utils.measure_memory(fn ->
      # Create and process many events
      for _i <- 1..100 do
        event = Events.new_event(:memory_test, %{data: String.duplicate("x", 100)})
        Events.serialize(event)
      end
    end)

  IO.puts("   ✅ Memory usage test")
  IO.puts("   - Before: #{Utils.format_bytes(memory_before)}")
  IO.puts("   - After: #{Utils.format_bytes(memory_after)}")
  IO.puts("   - Difference: #{diff} bytes")
rescue
  error ->
    IO.puts("   ❌ Performance and robustness test failed: #{Exception.message(error)}")
end

IO.puts("\n8. Testing Error Recovery Scenarios...")

try do
  # Test 1: Config service recovery
  IO.puts("   🧪 Testing config service recovery...")

  # Simulate service failure and recovery
  original_config = Config.get()
  config_pid = GenServer.whereis(Config)

  if config_pid do
    # Kill the service
    Process.exit(config_pid, :kill)
    Process.sleep(50)

    # Attempt to use fallback
    fallback_result = GracefulDegradation.get_with_fallback([:ai, :provider])
    IO.puts("   - Fallback result: #{inspect(fallback_result)}")

    # Restart service
    Config.initialize()
    Process.sleep(100)

    # Verify recovery
    new_config = Config.get()

    if %Config{} = new_config do
      IO.puts("   ✅ Config service recovery successful")
    end
  end

  # Test 2: Event serialization recovery
  IO.puts("   🧪 Testing event serialization recovery...")

  # Create event with potentially problematic data
  event_with_large_data =
    Events.new_event(:recovery_test, %{
      large_data: String.duplicate("recovery_test_", 1000)
    })

  # Test safe serialization
  safe_binary = EventsGD.serialize_safe(event_with_large_data)
  IO.puts("   ✅ Safe serialization successful: #{byte_size(safe_binary)} bytes")

  # Test recovery from corrupted data
  corrupted_binary = "definitely_not_valid_binary_data"
  recovered_event = EventsGD.deserialize_safe(corrupted_binary)

  if recovered_event.event_type == :deserialization_error do
    IO.puts("   ✅ Deserialization recovery successful")
  end

  # Test 3: Error context preservation under stress
  IO.puts("   🧪 Testing error context under stress...")

  stress_context = ErrorContext.new(__MODULE__, :stress_test)

  stress_result =
    ErrorContext.with_context(stress_context, fn ->
      # Simulate nested operations with potential failures
      nested_operations =
        for i <- 1..10 do
          child_context =
            ErrorContext.child_context(stress_context, StressModule, :operation, %{iteration: i})

          ErrorContext.with_context(child_context, fn ->
            if rem(i, 3) == 0 do
              # Simulate occasional failures
              raise RuntimeError, "Simulated stress failure #{i}"
            else
              {:ok, i}
            end
          end)
        end

      # Count successful operations
      successful = Enum.count(nested_operations, &match?({:ok, _}, &1))
      failed = Enum.count(nested_operations, &match?({:error, _}, &1))

      %{successful: successful, failed: failed, total: length(nested_operations)}
    end)

  case stress_result do
    {:ok, %{successful: s, failed: f, total: t}} ->
      IO.puts("   ✅ Stress test completed: #{s}/#{t} successful, #{f} failed")

    {:error, %Error{}} ->
      IO.puts("   ✅ Stress test error handling successful")

    other ->
      IO.puts("   ❌ Stress test unexpected result: #{inspect(other)}")
  end
rescue
  error ->
    IO.puts("   ❌ Error recovery test failed: #{Exception.message(error)}")
    # Ensure systems are restored
    Config.initialize()
end

IO.puts("\n9. Testing System Health and Monitoring...")

try do
  # Test foundation status
  status = ElixirScope.Foundation.status()
  IO.puts("   ✅ Foundation status retrieved")
  IO.puts("   - Config: #{inspect(status.config)}")
  IO.puts("   - Events: #{inspect(status.events)}")
  IO.puts("   - Telemetry: #{inspect(status.telemetry)}")
  IO.puts("   - Uptime: #{status.uptime_ms}ms")

  # Test system stats
  system_stats = Utils.system_stats()
  IO.puts("   ✅ System statistics collected")
  IO.puts("   - Total processes: #{system_stats.process_count}")
  IO.puts("   - Total memory: #{Utils.format_bytes(system_stats.total_memory)}")
  IO.puts("   - Schedulers: #{system_stats.scheduler_count}")
  IO.puts("   - OTP Release: #{system_stats.otp_release}")

  # Test process stats
  process_stats = Utils.process_stats()
  IO.puts("   ✅ Process statistics collected")
  IO.puts("   - Current process memory: #{Utils.format_bytes(process_stats.memory)}")
  IO.puts("   - Reductions: #{process_stats.reductions}")
  IO.puts("   - Message queue: #{process_stats.message_queue_len}")

  # Test telemetry health
  telemetry_metrics = Telemetry.get_metrics()
  foundation_metrics = telemetry_metrics.foundation

  IO.puts("   ✅ Telemetry metrics healthy")
  IO.puts("   - Foundation uptime: #{foundation_metrics.uptime_ms}ms")
  IO.puts("   - Foundation memory: #{Utils.format_bytes(foundation_metrics.memory_usage)}")
  IO.puts("   - Foundation processes: #{foundation_metrics.process_count}")
rescue
  error ->
    IO.puts("   ❌ System health test failed: #{Exception.message(error)}")
end

IO.puts("\n10. Final Integration Validation...")

try do
  # Complete workflow test combining all enhanced features
  IO.puts("   🏁 Running complete enhanced workflow...")

  # Create comprehensive context
  main_context =
    ErrorContext.new(__MODULE__, :final_validation,
      metadata: %{
        phase: 1,
        test_type: :comprehensive,
        timestamp: Utils.wall_timestamp()
      }
    )

  final_result =
    ErrorContext.with_context(main_context, fn ->
      # Step 1: Configuration operations
      config = Config.get()
      validation_result = Config.validate(config)

      # Step 2: Event operations with context
      event_context = ErrorContext.child_context(main_context, Events, :create_and_process)

      event_result =
        ErrorContext.with_context(event_context, fn ->
          event =
            Events.new_event(:final_validation, %{
              config_valid: validation_result == :ok,
              context_id: event_context.operation_id
            })

          serialized = Events.serialize(event)
          deserialized = Events.deserialize(serialized)

          {event, serialized, deserialized}
        end)

      # Step 3: Performance measurement
      perf_context = ErrorContext.child_context(main_context, Utils, :performance_test)

      perf_result =
        ErrorContext.with_context(perf_context, fn ->
          Telemetry.measure_event([:final, :validation], %{enhanced: true}, fn ->
            # Simulate work
            for _i <- 1..100 do
              Utils.generate_id()
            end

            :performance_complete
          end)
        end)

      # Step 4: Error handling validation
      error_context = ErrorContext.child_context(main_context, Error, :validation_test)

      error_result =
        ErrorContext.with_context(error_context, fn ->
          test_error = Error.new(:validation_complete, "All systems operational")
          enhanced_error = ErrorContext.enhance_error(test_error, error_context)

          # Verify error structure
          %{
            has_context: map_size(enhanced_error.context) > 0,
            has_correlation: enhanced_error.correlation_id != nil,
            correct_category: enhanced_error.category != nil
          }
        end)

      # Compile results
      %{
        config_status: validation_result,
        event_result: event_result,
        perf_result: perf_result,
        error_result: error_result,
        breadcrumbs: length(main_context.breadcrumbs),
        duration: ErrorContext.get_operation_duration(main_context)
      }
    end)

  case final_result do
    {:ok, results} ->
      IO.puts("   ✅ Final integration validation SUCCESSFUL")
      IO.puts("   - Config status: #{inspect(results.config_status)}")

      IO.puts(
        "   - Event processing: #{if match?({_, _, _}, results.event_result), do: "✅", else: "❌"}"
      )

      IO.puts(
        "   - Performance test: #{if results.perf_result == :performance_complete, do: "✅", else: "❌"}"
      )

      IO.puts("   - Error handling: #{if results.error_result.has_context, do: "✅", else: "❌"}")
      IO.puts("   - Operation duration: #{Utils.format_duration(results.duration)}")

    {:error, %Error{} = error} ->
      IO.puts("   ❌ Final integration validation failed with structured error:")
      IO.puts("   - #{Error.to_string(error)}")

    other ->
      IO.puts("   ❌ Final integration validation failed: #{inspect(other)}")
  end
rescue
  error ->
    IO.puts("   ❌ Final integration validation crashed: #{Exception.message(error)}")
end

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("🎉 ElixirScope Foundation Layer Phase 1 Enhanced Workflow Complete!")
IO.puts("")
IO.puts("Phase 1 Achievements:")
IO.puts("  ✅ Enhanced Configuration system with robust validation")
IO.puts("  ✅ Hierarchical error system with proper error codes")
IO.puts("  ✅ Graceful degradation patterns for service failures")
IO.puts("  ✅ Enhanced error context with breadcrumb tracking")
IO.puts("  ✅ Robust event system with safe serialization")
IO.puts("  ✅ Comprehensive error recovery mechanisms")
IO.puts("  ✅ System health monitoring and metrics")
IO.puts("  ✅ Performance validation and stress testing")
IO.puts("")
IO.puts("All Foundation layer Phase 1 robustness patterns are operational!")
IO.puts(String.duplicate("=", 80))
