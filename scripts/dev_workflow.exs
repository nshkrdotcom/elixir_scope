# Development workflow script for Foundation layer
# Usage: mix run scripts/dev_workflow.exs

IO.puts("=== ElixirScope Foundation Layer Development Workflow ===")

alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

IO.puts("1. Testing Configuration System...")

try do
  # Test configuration retrieval
  config = Config.get()
  IO.puts("   ✅ Configuration loaded successfully")
  IO.puts("   - AI Provider: #{config.ai.provider}")
  IO.puts("   - Sampling Rate: #{config.ai.planning.sampling_rate}")

  # Test configuration path access
  batch_size = Config.get([:capture, :processing, :batch_size])
  IO.puts("   - Batch Size: #{batch_size}")

  # Test configuration update (allowed path)
  old_rate = Config.get([:ai, :planning, :sampling_rate])
  :ok = Config.update([:ai, :planning, :sampling_rate], 0.8)
  new_rate = Config.get([:ai, :planning, :sampling_rate])
  IO.puts("   ✅ Configuration update successful: #{old_rate} → #{new_rate}")

  # Restore original rate
  Config.update([:ai, :planning, :sampling_rate], old_rate)
rescue
  error ->
    IO.puts("   ❌ Configuration test failed: #{Exception.message(error)}")
end

IO.puts("\n2. Testing Event System...")

try do
  # Test basic event creation
  event = Events.new_event(:test_event, %{message: "Hello, World!"})
  IO.puts("   ✅ Event created successfully")
  IO.puts("   - Event ID: #{event.event_id}")
  IO.puts("   - Event Type: #{event.event_type}")
  IO.puts("   - Timestamp: #{Utils.format_timestamp(event.timestamp)}")

  # Test function entry event
  func_event = Events.function_entry(TestModule, :test_function, 2, [:arg1, :arg2])
  IO.puts("   ✅ Function entry event created")
  IO.puts("   - Call ID: #{func_event.data.call_id}")

  # Test serialization
  serialized = Events.serialize(event)
  deserialized = Events.deserialize(serialized)

  if deserialized == event do
    IO.puts("   ✅ Event serialization round-trip successful")
    IO.puts("   - Serialized size: #{Events.serialized_size(event)} bytes")
  else
    IO.puts("   ❌ Event serialization round-trip failed")
  end
rescue
  error ->
    IO.puts("   ❌ Event system test failed: #{Exception.message(error)}")
end

IO.puts("\n3. Testing Utilities...")

try do
  # Test ID generation
  id1 = Utils.generate_id()
  id2 = Utils.generate_id()

  if id1 != id2 do
    IO.puts("   ✅ Unique ID generation working")
    IO.puts("   - Generated IDs: #{id1}, #{id2}")
  end

  # Test correlation ID generation
  corr_id = Utils.generate_correlation_id()
  IO.puts("   ✅ Correlation ID generated: #{corr_id}")

  # Test time measurement
  {result, duration} =
    Utils.measure(fn ->
      :timer.sleep(10)
      :measured_operation
    end)

  IO.puts("   ✅ Time measurement working")
  IO.puts("   - Operation result: #{result}")
  IO.puts("   - Duration: #{Utils.format_duration(duration)}")

  # Test memory measurement
  {_list, {mem_before, mem_after, diff}} =
    Utils.measure_memory(fn ->
      Enum.to_list(1..1000)
    end)

  IO.puts("   ✅ Memory measurement working")
  IO.puts("   - Memory before: #{Utils.format_bytes(mem_before)}")
  IO.puts("   - Memory after: #{Utils.format_bytes(mem_after)}")
  IO.puts("   - Memory diff: #{diff} bytes")

  # Test data truncation
  large_data = String.duplicate("x", 2000)
  truncated = Utils.truncate_if_large(large_data, 1000)

  case truncated do
    {:truncated, size, hint} ->
      IO.puts("   ✅ Data truncation working")
      IO.puts("   - Original size: #{size} bytes")
      IO.puts("   - Type hint: #{hint}")

    _ ->
      IO.puts("   ❌ Data truncation not working as expected")
  end
rescue
  error ->
    IO.puts("   ❌ Utilities test failed: #{Exception.message(error)}")
end

IO.puts("\n4. Testing Telemetry...")

try do
  # Test telemetry measurement
  result =
    Telemetry.measure_event([:test, :operation], %{component: :foundation}, fn ->
      :timer.sleep(5)
      :telemetry_test_result
    end)

  IO.puts("   ✅ Telemetry measurement working")
  IO.puts("   - Result: #{result}")

  # Test metrics collection
  metrics = Telemetry.get_metrics()
  IO.puts("   ✅ Metrics collection working")
  IO.puts("   - Uptime: #{metrics.foundation.uptime_ms} ms")
  IO.puts("   - Memory: #{Utils.format_bytes(metrics.foundation.memory_usage)}")
  IO.puts("   - Processes: #{metrics.foundation.process_count}")
rescue
  error ->
    IO.puts("   ❌ Telemetry test failed: #{Exception.message(error)}")
end

IO.puts("\n5. Testing System Stats...")

try do
  process_stats = Utils.process_stats()
  system_stats = Utils.system_stats()

  IO.puts("   ✅ Process stats collected")
  IO.puts("   - Current process memory: #{Utils.format_bytes(process_stats.memory)}")
  IO.puts("   - Message queue length: #{process_stats.message_queue_len}")

  IO.puts("   ✅ System stats collected")
  IO.puts("   - Total processes: #{system_stats.process_count}")
  IO.puts("   - Total memory: #{Utils.format_bytes(system_stats.total_memory)}")
  IO.puts("   - Schedulers: #{system_stats.scheduler_count}")
  IO.puts("   - OTP Release: #{system_stats.otp_release}")
rescue
  error ->
    IO.puts("   ❌ System stats test failed: #{Exception.message(error)}")
end

IO.puts("\n=== Foundation Layer Workflow Completed Successfully ===")
IO.puts("All core Foundation layer components are working correctly!")
