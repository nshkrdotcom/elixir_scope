# Registry Performance Benchmark Script
#
# Validates the documented performance characteristics of the ElixirScope Foundation Registry
# and provides empirical data for optimization decisions.

defmodule RegistryBenchmark do
  @moduledoc """
  Comprehensive benchmarking suite for ElixirScope Foundation Registry performance.

  Tests:
  - Service lookup latency under various loads
  - Registration performance with concurrent access
  - Memory usage patterns
  - Partition utilization efficiency
  - Namespace isolation overhead
  """

  alias ElixirScope.Foundation.{ProcessRegistry, ServiceRegistry}

  def run_all_benchmarks do
    IO.puts("🚀 ElixirScope Foundation Registry Performance Benchmark")
    IO.puts("=" |> String.duplicate(60))

    # System information
    print_system_info()

    # Run benchmarks
    benchmark_lookup_performance()
    benchmark_registration_performance()
    benchmark_namespace_isolation()
    benchmark_concurrent_access()
    benchmark_memory_usage()

    IO.puts("\n✅ Benchmark suite completed")
  end

  defp print_system_info do
    IO.puts("\n📊 System Information:")
    IO.puts("  - Schedulers: #{System.schedulers_online()}")
    IO.puts("  - Registry Partitions: #{System.schedulers_online()}")
    IO.puts("  - OTP Version: #{System.otp_release()}")
    IO.puts("  - Elixir Version: #{System.version()}")

    # Registry stats if available
    try do
      stats = ProcessRegistry.stats()
      IO.puts("  - Current Services: #{stats.total_services}")
      IO.puts("  - Memory Usage: #{stats.memory_usage_bytes} bytes")
    rescue
      _ -> IO.puts("  - Registry not initialized")
    end
  end

  defp benchmark_lookup_performance do
    IO.puts("\n🔍 Lookup Performance Benchmark")

    # Setup test services
    test_ref = make_ref()
    namespace = {:test, test_ref}

    # Register test services
    services = [:service_1, :service_2, :service_3, :service_4, :service_5]

    pids =
      Enum.map(services, fn service ->
        {:ok, pid} = Agent.start_link(fn -> %{} end)
        :ok = ProcessRegistry.register(namespace, service, pid)
        {service, pid}
      end)

    # Simple timing benchmark without Benchee
    iterations = 10_000

    IO.puts("  Testing #{iterations} iterations...")

    # ProcessRegistry.lookup/2 benchmark
    start_time = System.monotonic_time(:millisecond)

    for _ <- 1..iterations do
      ProcessRegistry.lookup(namespace, :service_1)
    end

    process_registry_time = System.monotonic_time(:millisecond) - start_time

    # ServiceRegistry.lookup/2 benchmark
    start_time = System.monotonic_time(:millisecond)

    for _ <- 1..iterations do
      ServiceRegistry.lookup(namespace, :service_1)
    end

    service_registry_time = System.monotonic_time(:millisecond) - start_time

    # ServiceRegistry.health_check/2 benchmark
    start_time = System.monotonic_time(:millisecond)

    for _ <- 1..iterations do
      ServiceRegistry.health_check(namespace, :service_1)
    end

    health_check_time = System.monotonic_time(:millisecond) - start_time

    IO.puts("  Results:")

    IO.puts(
      "    ProcessRegistry.lookup/2:    #{process_registry_time}ms (#{Float.round(iterations / process_registry_time, 1)} ops/ms)"
    )

    IO.puts(
      "    ServiceRegistry.lookup/2:    #{service_registry_time}ms (#{Float.round(iterations / service_registry_time, 1)} ops/ms)"
    )

    IO.puts(
      "    ServiceRegistry.health_check/2: #{health_check_time}ms (#{Float.round(iterations / health_check_time, 1)} ops/ms)"
    )

    # Cleanup
    Enum.each(pids, fn {_service, pid} ->
      try do
        if Process.alive?(pid), do: Agent.stop(pid)
      catch
        # Process may have already exited
        :exit, _ -> :ok
      end
    end)

    ProcessRegistry.cleanup_test_namespace(test_ref)
  end

  defp benchmark_registration_performance do
    IO.puts("\n📝 Registration Performance Benchmark")

    test_ref = make_ref()
    namespace = {:test, test_ref}
    iterations = 1_000

    IO.puts("  Testing #{iterations} registrations...")

    # Registration benchmark
    start_time = System.monotonic_time(:millisecond)

    pids =
      for i <- 1..iterations do
        {:ok, pid} = Agent.start_link(fn -> %{} end)
        service = :"service_#{i}"
        :ok = ProcessRegistry.register(namespace, service, pid)
        pid
      end

    registration_time = System.monotonic_time(:millisecond) - start_time

    IO.puts("  Results:")

    IO.puts(
      "    #{iterations} registrations: #{registration_time}ms (#{Float.round(iterations / registration_time, 1)} ops/ms)"
    )

    # Cleanup
    Enum.each(pids, fn pid ->
      try do
        if Process.alive?(pid), do: Agent.stop(pid)
      catch
        # Process may have already exited
        :exit, _ -> :ok
      end
    end)

    ProcessRegistry.cleanup_test_namespace(test_ref)
  end

  defp benchmark_namespace_isolation do
    IO.puts("\n🏠 Namespace Isolation Overhead Benchmark")

    # Setup multiple namespaces
    test_refs = for _ <- 1..5, do: make_ref()
    namespaces = Enum.map(test_refs, &{:test, &1})

    # Register same service name in each namespace
    Enum.each(namespaces, fn namespace ->
      {:ok, pid} = Agent.start_link(fn -> %{} end)
      ProcessRegistry.register(namespace, :isolated_service, pid)
    end)

    iterations = 5_000
    IO.puts("  Testing #{iterations} operations...")

    # Test namespace lookup
    start_time = System.monotonic_time(:millisecond)

    for _ <- 1..iterations do
      namespace = Enum.random(namespaces)
      ProcessRegistry.lookup(namespace, :isolated_service)
    end

    namespace_time = System.monotonic_time(:millisecond) - start_time

    IO.puts("  Results:")

    IO.puts(
      "    Test Namespace Lookups: #{namespace_time}ms (#{Float.round(iterations / namespace_time, 1)} ops/ms)"
    )

    # Cleanup
    Enum.each(test_refs, &ProcessRegistry.cleanup_test_namespace/1)
  end

  defp benchmark_concurrent_access do
    IO.puts("\n⚡ Concurrent Access Performance Benchmark")

    test_ref = make_ref()
    namespace = {:test, test_ref}

    # Pre-register some services
    services =
      for i <- 1..20 do
        service = :"concurrent_service_#{i}"
        {:ok, pid} = Agent.start_link(fn -> %{} end)
        ProcessRegistry.register(namespace, service, pid)
        {service, pid}
      end

    IO.puts("  - Testing with #{length(services)} pre-registered services")
    IO.puts("  - Scheduler count: #{System.schedulers_online()}")

    # Concurrent lookup test
    iterations_per_task = 1_000
    task_count = 4

    start_time = System.monotonic_time(:millisecond)

    tasks =
      for _ <- 1..task_count do
        Task.async(fn ->
          for _ <- 1..iterations_per_task do
            service = :"concurrent_service_#{:rand.uniform(20)}"
            ProcessRegistry.lookup(namespace, service)
          end
        end)
      end

    Task.await_many(tasks)
    concurrent_time = System.monotonic_time(:millisecond) - start_time

    total_operations = task_count * iterations_per_task
    IO.puts("  Results:")

    IO.puts(
      "    #{total_operations} concurrent lookups: #{concurrent_time}ms (#{Float.round(total_operations / concurrent_time, 1)} ops/ms)"
    )

    # Cleanup
    Enum.each(services, fn {_service, pid} ->
      try do
        if Process.alive?(pid), do: Agent.stop(pid)
      catch
        # Process may have already exited
        :exit, _ -> :ok
      end
    end)

    ProcessRegistry.cleanup_test_namespace(test_ref)
  end

  defp benchmark_memory_usage do
    IO.puts("\n💾 Memory Usage Analysis")

    # Baseline memory measurement
    :erlang.garbage_collect()
    {_, _baseline_memory} = :erlang.process_info(self(), :memory)

    test_ref = make_ref()
    namespace = {:test, test_ref}

    # Register increasing numbers of services and measure memory
    service_counts = [10, 50, 100, 500, 1000]

    IO.puts("  Service Count | Memory Usage (bytes) | Per-Service (bytes)")
    IO.puts("  " <> String.duplicate("-", 55))

    Enum.each(service_counts, fn count ->
      # Register services
      services =
        for i <- 1..count do
          service = :"memory_test_service_#{i}"
          {:ok, pid} = Agent.start_link(fn -> %{} end)
          ProcessRegistry.register(namespace, service, pid)
          {service, pid}
        end

      # Force garbage collection and measure
      :erlang.garbage_collect()
      # Allow GC to complete
      Process.sleep(10)

      stats = ProcessRegistry.stats()
      memory_usage = stats.memory_usage_bytes
      per_service = if count > 0, do: div(memory_usage, count), else: 0

      IO.puts(
        "  #{String.pad_leading("#{count}", 12)} | #{String.pad_leading("#{memory_usage}", 19)} | #{String.pad_leading("#{per_service}", 16)}"
      )

      # Cleanup for next iteration
      Enum.each(services, fn {_service, pid} ->
        try do
          if Process.alive?(pid), do: Agent.stop(pid)
        catch
          # Process may have already exited
          :exit, _ -> :ok
        end
      end)
    end)

    ProcessRegistry.cleanup_test_namespace(test_ref)

    # Final stats
    final_stats = ProcessRegistry.stats()
    IO.puts("\n  Final Registry Statistics:")
    IO.puts("  - Total Services: #{final_stats.total_services}")
    IO.puts("  - Production Services: #{final_stats.production_services}")
    IO.puts("  - Test Namespaces: #{final_stats.test_namespaces}")
    IO.puts("  - Memory Usage: #{final_stats.memory_usage_bytes} bytes")
  end
end

# Run benchmarks if script is executed directly
try do
  # Check if we're running in a Mix environment
  if Mix.env() == :dev do
    # Ensure the application is started
    Application.ensure_all_started(:elixir_scope)

    # Wait a moment for services to initialize
    Process.sleep(100)

    RegistryBenchmark.run_all_benchmarks()
  else
    IO.puts("Registry benchmarks should be run in :dev environment")
    IO.puts("Usage: MIX_ENV=dev mix run scripts/registry_benchmark.exs")
  end
rescue
  UndefinedFunctionError ->
    # Running outside Mix environment, start application directly
    Code.require_file("#{__DIR__}/../lib/elixir_scope.ex")
    Application.ensure_all_started(:elixir_scope)
    Process.sleep(100)
    RegistryBenchmark.run_all_benchmarks()
catch
  error ->
    IO.puts("Error running benchmarks: #{inspect(error)}")

    IO.puts(
      "Please run with: cd /path/to/project && MIX_ENV=dev mix run scripts/registry_benchmark.exs"
    )
end
