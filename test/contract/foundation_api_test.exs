defmodule ElixirScope.Contract.FoundationAPITest do
  use ExUnit.Case, async: false

  alias ElixirScope.Foundation
  alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

  describe "Foundation layer API contracts" do
    test "Foundation.initialize/1 contract" do
      # Should accept keyword list and return :ok or error
      assert :ok = Foundation.initialize([])
      assert :ok = Foundation.initialize(dev: %{debug_mode: true})
    end

    test "Foundation.status/0 contract" do
      status = Foundation.status()

      # Should return map with required keys
      assert is_map(status)
      assert Map.has_key?(status, :config)
      assert Map.has_key?(status, :events)
      assert Map.has_key?(status, :telemetry)
      assert Map.has_key?(status, :uptime_ms)

      # Values should be status indicators or metrics
      assert status.config == :ok or match?({:error, _}, status.config)
      assert is_integer(status.uptime_ms)
    end
  end

  describe "Config API contracts" do
    setup do
      :ok = ElixirScope.Foundation.TestHelpers.ensure_config_available()
      :ok
    end

    test "Config.get/0 returns Config struct" do
      config = Config.get()
      assert %{} = config
    end

    test "Config.get/1 with path returns value or nil" do
      result = Config.get([:ai, :provider])
      assert result != nil

      result = Config.get([:nonexistent, :path])
      assert result == nil
    end

    test "Config.update/2 respects allowed paths" do
      # Should succeed for allowed paths
      result = Config.update([:ai, :planning, :sampling_rate], 0.5)
      assert result == :ok

      # Should fail for forbidden paths
      result = Config.update([:ai, :provider], :different_provider)
      assert result == {:error, :not_updatable}
    end

    test "Config.validate/1 returns ok or error tuple" do
      valid_config = %{}
      assert {:ok, ^valid_config} = Config.validate(valid_config)

      invalid_config = %{ai: %{provider: :invalid}}
      assert {:error, _reason} = Config.validate(invalid_config)
    end
  end

  describe "Events API contracts" do
    test "Events.new_event/3 creates valid event" do
      event = Events.new_event(:test_type, %{data: "test"}, [])

      assert %{} = event
      assert event.event_type == :test_type
      assert is_integer(event.event_id)
      assert is_integer(event.timestamp)
    end

    test "Events serialization contracts" do
      event = Events.new_event(:test, %{})

      # Serialize should return binary
      serialized = Events.serialize(event)
      assert is_binary(serialized)

      # Deserialize should return original event
      deserialized = Events.deserialize(serialized)
      assert deserialized == event

      # Size should be non-negative integer
      size = Events.serialized_size(event)
      assert is_integer(size)
      assert size >= 0
    end
  end

  describe "Utils API contracts" do
    test "ID generation contracts" do
      # generate_id should return positive integer
      id = Utils.generate_id()
      assert is_integer(id)
      assert id > 0

      # generate_correlation_id should return UUID string
      corr_id = Utils.generate_correlation_id()
      assert is_binary(corr_id)
      assert String.length(corr_id) == 36
    end

    test "measurement contracts" do
      # measure should return {result, duration} tuple
      {result, duration} = Utils.measure(fn -> :test_result end)
      assert result == :test_result
      assert is_integer(duration)
      assert duration >= 0

      # measure_memory should return {result, {before, after, diff}} tuple
      {result, {before, and_after, diff}} = Utils.measure_memory(fn -> :test_result end)
      assert result == :test_result
      assert is_integer(before)
      assert is_integer(and_after)
      assert is_integer(diff)
    end

    test "formatting contracts" do
      # Should return strings
      assert is_binary(Utils.format_bytes(1024))
      assert is_binary(Utils.format_duration(1_000_000))
      assert is_binary(Utils.format_timestamp(Utils.wall_timestamp()))

      # Should handle edge cases
      assert is_binary(Utils.format_bytes(0))
      assert is_binary(Utils.format_duration(0))
    end

    test "validation contracts" do
      # Should return boolean
      assert is_boolean(Utils.valid_positive_integer?(1))
      assert is_boolean(Utils.valid_percentage?(0.5))
      assert is_boolean(Utils.valid_pid?(self()))
    end
  end

  describe "Telemetry API contracts" do
    test "measurement and emission contracts" do
      # measure_event should return function result
      result = Telemetry.measure_event([:test], %{}, fn -> :measured end)
      assert result == :measured

      # emit functions should return :ok
      assert :ok = Telemetry.emit_counter([:test])
      assert :ok = Telemetry.emit_gauge([:test], 42.0)
    end

    test "metrics contract" do
      metrics = Telemetry.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :foundation)
      assert Map.has_key?(metrics, :system)
    end
  end
end
