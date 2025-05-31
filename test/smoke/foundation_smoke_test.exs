defmodule ElixirScope.Smoke.FoundationTest do
  @moduledoc """
  Smoke tests for Foundation layer - validates core workflows work
  without testing implementation details.
  """

  use ExUnit.Case
  @moduletag :foundation

  alias ElixirScope.Foundation
  alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry, Error}

  describe "foundation layer initialization" do
    test "foundation layer can be initialized" do
      # Should not crash and should return success
      assert :ok = Foundation.initialize()

      # Should be able to get status
      status = Foundation.status()
      assert is_map(status)
      assert Map.has_key?(status, :config)
      assert Map.has_key?(status, :events)
      assert Map.has_key?(status, :telemetry)
    end
  end

  describe "configuration smoke tests" do
    test "can get configuration" do
      config = Config.get()
      assert %Config{} = config
      assert config.ai.provider == :mock
    end

    test "can get configuration by path" do
      provider = Config.get([:ai, :provider])
      assert provider == :mock

      batch_size = Config.get([:capture, :processing, :batch_size])
      assert is_integer(batch_size)
      assert batch_size > 0
    end

    test "can update allowed configuration paths" do
      original_rate = Config.get([:ai, :planning, :sampling_rate])

      # Update to a different value
      new_rate = if original_rate == 1.0, do: 0.8, else: 1.0
      assert :ok = Config.update([:ai, :planning, :sampling_rate], new_rate)

      # Verify update
      updated_rate = Config.get([:ai, :planning, :sampling_rate])
      assert updated_rate == new_rate

      # Restore original
      Config.update([:ai, :planning, :sampling_rate], original_rate)
    end

    test "rejects updates to forbidden paths" do
      result = Config.update([:ai, :provider], :openai)
      assert {:error, %Error{error_type: :config_update_forbidden}} = result
    end
  end

  describe "events smoke tests" do
    test "can create basic events" do
      event = Events.new_event(:test_event, %{data: "test"})

      assert %Events{} = event
      assert event.event_type == :test_event
      assert event.data.data == "test"
      assert is_integer(event.event_id)
      assert is_integer(event.timestamp)
    end

    test "can create function events" do
      event = Events.function_entry(TestModule, :test_function, 1, [:arg])

      assert event.event_type == :function_entry
      assert event.data.module == TestModule
      assert event.data.function == :test_function
      assert event.data.arity == 1
    end

    test "can serialize and deserialize events" do
      original = Events.new_event(:test, %{data: "serialize_test"})

      serialized = Events.serialize(original)
      assert is_binary(serialized)

      deserialized = Events.deserialize(serialized)
      assert deserialized == original
    end
  end

  describe "utilities smoke tests" do
    test "can generate unique IDs" do
      id1 = Utils.generate_id()
      id2 = Utils.generate_id()

      assert is_integer(id1)
      assert is_integer(id2)
      assert id1 != id2
    end

    test "can generate correlation IDs" do
      corr_id = Utils.generate_correlation_id()

      assert is_binary(corr_id)
      # UUID format
      assert String.length(corr_id) == 36
    end

    test "can measure execution time" do
      {result, duration} =
        Utils.measure(fn ->
          :timer.sleep(1)
          :test_result
        end)

      assert result == :test_result
      assert is_integer(duration)
      assert duration > 0
    end

    test "can format values" do
      assert is_binary(Utils.format_bytes(1024))
      assert is_binary(Utils.format_duration(1_000_000))
      assert is_binary(Utils.format_timestamp(Utils.wall_timestamp()))
    end

    test "can get process and system stats" do
      process_stats = Utils.process_stats()
      assert is_map(process_stats)
      assert Map.has_key?(process_stats, :memory)

      system_stats = Utils.system_stats()
      assert is_map(system_stats)
      assert Map.has_key?(system_stats, :process_count)
    end
  end

  describe "telemetry smoke tests" do
    test "can measure telemetry events" do
      result =
        Telemetry.measure_event([:test, :measurement], %{}, fn ->
          :measured_result
        end)

      assert result == :measured_result
    end

    test "can emit counters and gauges" do
      assert :ok = Telemetry.emit_counter([:test, :counter])
      assert :ok = Telemetry.emit_gauge([:test, :gauge], 42.0)
    end

    test "can get metrics" do
      metrics = Telemetry.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :foundation)
      assert Map.has_key?(metrics, :system)
    end
  end

  describe "error handling smoke tests" do
    test "error context works correctly" do
      # Test that ErrorContext can be used properly
      context = ElixirScope.Foundation.ErrorContext.new(__MODULE__, :test_function)
      assert is_map(context)
      assert context.module == __MODULE__
      assert context.function == :test_function
    end

    test "error handling preserves context" do
      # Test error context preservation through function calls
      result =
        ElixirScope.Foundation.ErrorContext.with_context(
          ElixirScope.Foundation.ErrorContext.new(__MODULE__, :test_error_handling),
          fn ->
            {:error, Error.new(:test_error, "Test error message")}
          end
        )

      assert {:error, %Error{error_type: :test_error}} = result
    end
  end

  describe "integration smoke tests" do
    test "components work together" do
      # Create an event
      event = Events.function_entry(TestModule, :integration_test, 0, [])

      # Measure serialization with telemetry
      result =
        Telemetry.measure_event([:test, :serialization], %{}, fn ->
          Events.serialize(event)
        end)

      assert is_binary(result)

      # Verify we can deserialize
      deserialized = Events.deserialize(result)
      assert deserialized == event
    end

    test "error handling works throughout the system" do
      # Test that errors propagate correctly through the system
      result = Config.update([:nonexistent, :path], :value)
      assert {:error, %Error{}} = result

      # System should still be functional
      assert %Config{} = Config.get()
    end
  end
end
