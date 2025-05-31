defmodule ElixirScope.Foundation.TelemetryTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Foundation.Telemetry

  describe "telemetry measurement" do
    test "measures event execution time" do
      result = Telemetry.measure_event([:test, :operation], %{component: :foundation}, fn ->
        :timer.sleep(5)
        :test_result
      end)

      assert result == :test_result
    end

    test "handles errors in measured events" do
      assert_raise RuntimeError, "test error", fn ->
        Telemetry.measure_event([:test, :error], %{}, fn ->
          raise RuntimeError, "test error"
        end)
      end
    end
  end

  describe "telemetry events" do
    test "emits counter events" do
      assert :ok = Telemetry.emit_counter([:test, :counter], %{source: :test})
    end

    test "emits gauge events" do
      assert :ok = Telemetry.emit_gauge([:test, :gauge], 42.5, %{unit: :percent})
    end
  end

  describe "metrics collection" do
    test "collects foundation metrics" do
      metrics = Telemetry.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :foundation)
      assert Map.has_key?(metrics, :system)

      foundation_metrics = metrics.foundation
      assert Map.has_key?(foundation_metrics, :uptime_ms)
      assert Map.has_key?(foundation_metrics, :memory_usage)
      assert Map.has_key?(foundation_metrics, :process_count)
    end
  end

  describe "initialization and status" do
    test "initializes successfully" do
      assert :ok = Telemetry.initialize()
    end

    test "reports healthy status" do
      assert :ok = Telemetry.status()
    end
  end
end
