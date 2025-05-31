# Performance benchmarking script for Foundation layer
# Usage: mix run scripts/benchmark.exs

defmodule FoundationBenchmark do
  alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

  def run_benchmarks do
    IO.puts("=== ElixirScope Foundation Layer Benchmarks ===\n")

    benchmark_id_generation()
    benchmark_event_creation()
    benchmark_serialization()
    benchmark_measurement()
    benchmark_configuration()

    IO.puts("=== Benchmarks Complete ===")
  end

  defp benchmark_id_generation do
    IO.puts("🔢 ID Generation Benchmarks:")

    # Benchmark integer ID generation
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000, do: Utils.generate_id()
      end)

    avg_time = time / 10_000
    IO.puts("  Integer IDs: #{Float.round(avg_time, 2)} μs/ID (10k IDs)")

    # Benchmark correlation ID generation
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..1_000, do: Utils.generate_correlation_id()
      end)

    avg_time = time / 1_000
    IO.puts("  Correlation IDs: #{Float.round(avg_time, 2)} μs/ID (1k IDs)")

    IO.puts("")
  end

  defp benchmark_event_creation do
    IO.puts("📝 Event Creation Benchmarks:")

    # Simple events
    {time, _} =
      :timer.tc(fn ->
        for i <- 1..10_000 do
          Events.new_event(:benchmark_event, %{sequence: i})
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Simple events: #{Float.round(avg_time, 2)} μs/event (10k events)")

    # Function events
    {time, _} =
      :timer.tc(fn ->
        for i <- 1..10_000 do
          Events.function_entry(BenchmarkModule, :test_function, 1, [i])
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Function events: #{Float.round(avg_time, 2)} μs/event (10k events)")

    IO.puts("")
  end

  defp benchmark_serialization do
    IO.puts("💾 Serialization Benchmarks:")

    # Create test events
    simple_event = Events.new_event(:test, %{data: "simple"})

    complex_event =
      Events.new_event(:complex, %{
        data: Enum.to_list(1..100),
        metadata: %{timestamp: Utils.wall_timestamp()},
        nested: %{deep: %{structure: [1, 2, 3]}}
      })

    # Benchmark simple event serialization
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000 do
          Events.serialize(simple_event)
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Simple serialize: #{Float.round(avg_time, 2)} μs/event (10k events)")

    # Benchmark complex event serialization
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..1_000 do
          Events.serialize(complex_event)
        end
      end)

    avg_time = time / 1_000
    IO.puts("  Complex serialize: #{Float.round(avg_time, 2)} μs/event (1k events)")

    # Benchmark deserialization
    serialized_simple = Events.serialize(simple_event)

    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000 do
          Events.deserialize(serialized_simple)
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Deserialize: #{Float.round(avg_time, 2)} μs/event (10k events)")

    IO.puts("")
  end

  defp benchmark_measurement do
    IO.puts("⏱️  Measurement Benchmarks:")

    # Time measurement overhead
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000 do
          Utils.measure(fn -> :ok end)
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Time measurement overhead: #{Float.round(avg_time, 2)} μs/measurement")

    # Memory measurement overhead
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..1_000 do
          Utils.measure_memory(fn -> :ok end)
        end
      end)

    avg_time = time / 1_000
    IO.puts("  Memory measurement overhead: #{Float.round(avg_time, 2)} μs/measurement")

    # Telemetry measurement overhead
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000 do
          Telemetry.measure_event([:benchmark], %{}, fn -> :ok end)
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Telemetry measurement overhead: #{Float.round(avg_time, 2)} μs/measurement")

    IO.puts("")
  end

  defp benchmark_configuration do
    IO.puts("⚙️  Configuration Benchmarks:")

    # Config get operations
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000 do
          Config.get()
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Full config get: #{Float.round(avg_time, 2)} μs/get")

    # Config path get operations
    {time, _} =
      :timer.tc(fn ->
        for _i <- 1..10_000 do
          Config.get([:ai, :planning, :sampling_rate])
        end
      end)

    avg_time = time / 10_000
    IO.puts("  Path config get: #{Float.round(avg_time, 2)} μs/get")

    # Config update operations
    {time, _} =
      :timer.tc(fn ->
        for i <- 1..1_000 do
          rate = if rem(i, 2) == 0, do: 0.8, else: 1.0
          Config.update([:ai, :planning, :sampling_rate], rate)
        end
      end)

    avg_time = time / 1_000
    IO.puts("  Config update: #{Float.round(avg_time, 2)} μs/update")

    IO.puts("")
  end
end

FoundationBenchmark.run_benchmarks()
