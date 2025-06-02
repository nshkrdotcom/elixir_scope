defmodule ElixirScope.Foundation.Infrastructure do
  @moduledoc """
  Integrated infrastructure system for Foundation layer.

  Coordinates all infrastructure components:
  - Circuit Breaker Framework
  - Memory Management Framework
  - Enhanced Health Check System
  - Performance Monitoring Infrastructure
  - Rate Limiting Framework
  - Connection Pooling Infrastructure

  This module provides a unified interface for infrastructure management
  and demonstrates how components work together.
  """

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}
  alias ElixirScope.Foundation.Infrastructure.{
    CircuitBreaker,
    MemoryManager,
    HealthAggregator,
    PerformanceMonitor,
    TokenBucketLimiter,
    ConnectionPoolRegistry
  }

  @type t :: infrastructure_config()

  @type infrastructure_config :: %{
    memory_manager: map(),
    performance_monitor: map(),
    health_aggregator: map(),
    rate_limiters: map(),
    circuit_breakers: map(),
    connection_pools: map()
  }

  @doc """
  Initialize all infrastructure components for a namespace.
  """
  @spec initialize_infrastructure(ServiceRegistry.namespace(), keyword()) :: :ok | {:error, term()}
  def initialize_infrastructure(namespace, opts \\ []) do
    config = Keyword.get(opts, :config, default_infrastructure_config())

    with :ok <- start_memory_manager(namespace, config.memory),
         :ok <- start_performance_monitor(namespace, config.performance),
         :ok <- start_health_aggregator(namespace, config.health),
         :ok <- start_rate_limiters(namespace, config.rate_limiting),
         :ok <- setup_circuit_breakers(namespace, config.circuit_breakers),
         :ok <- setup_connection_pools(namespace, config.connection_pools) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get comprehensive infrastructure health for a namespace.
  """
  @spec get_infrastructure_health(ServiceRegistry.namespace()) :: {:ok, map()} | {:error, term()}
  def get_infrastructure_health(namespace) do
    with {:ok, system_health} <- HealthAggregator.system_health(namespace),
         {:ok, memory_stats} <- MemoryManager.get_stats(namespace),
         {:ok, performance_summary} <- PerformanceMonitor.get_performance_summary(namespace),
         {:ok, pool_stats} <- ConnectionPoolRegistry.get_all_pool_stats(namespace) do

      infrastructure_health = %{
        timestamp: DateTime.utc_now(),
        namespace: namespace,
        overall_status: determine_overall_infrastructure_status(system_health, memory_stats),
        system_health: system_health,
        memory: %{
          stats: memory_stats,
          pressure_level: MemoryManager.check_pressure(namespace)
        },
        performance: performance_summary,
        connection_pools: pool_stats,
        circuit_breakers: get_circuit_breaker_health(namespace)
      }

      {:ok, infrastructure_health}
    else
      error -> error
    end
  end

  @doc """
  Execute operation with full infrastructure protection.
  """
  @spec protected_operation(ServiceRegistry.namespace(), atom(), keyword(), (-> term())) ::
    {:ok, term()} | {:error, term()}
  def protected_operation(namespace, service, opts, operation) when is_function(operation, 0) do
    rate_key = Keyword.get(opts, :rate_key, service)
    rate_config = Keyword.get(opts, :rate_config, default_rate_config())

    with :ok <- check_memory_pressure(namespace),
         :ok <- check_rate_limit(namespace, rate_key, rate_config),
         {:ok, result} <- execute_with_circuit_breaker(namespace, service, operation) do

      # Record performance metrics
      record_operation_success(namespace, service)
      {:ok, result}
    else
      {:error, reason} = error ->
        record_operation_failure(namespace, service, reason)
        error
    end
  end

  @doc """
  Update Foundation services with infrastructure protection.
  """
  @spec update_service_with_infrastructure(module(), keyword()) :: :ok | {:error, term()}
  def update_service_with_infrastructure(service_module, opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :production)

    # Add infrastructure mixins to the service
    quote do
      defmodule unquote(service_module).Enhanced do
        use unquote(service_module)
        use ElixirScope.Foundation.Infrastructure.ServiceProtection

        # Override critical operations with infrastructure protection
        def protected_call(operation, args) do
          ElixirScope.Foundation.Infrastructure.protected_operation(
            unquote(namespace),
            unquote(service_module),
            [rate_key: {unquote(service_module), operation}],
            fn -> apply(unquote(service_module), operation, args) end
          )
        end
      end
    end
  end

  ## Private Functions

  @spec start_memory_manager(ServiceRegistry.namespace(), map()) :: :ok | {:error, term()}
  defp start_memory_manager(namespace, config) do
    case MemoryManager.start_link([namespace: namespace, config: config]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, {:memory_manager_failed, reason}}
    end
  end

  @spec start_performance_monitor(ServiceRegistry.namespace(), map()) :: :ok | {:error, term()}
  defp start_performance_monitor(namespace, config) do
    case PerformanceMonitor.start_link([namespace: namespace, config: config]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, {:performance_monitor_failed, reason}}
    end
  end

  @spec start_health_aggregator(ServiceRegistry.namespace(), map()) :: :ok | {:error, term()}
  defp start_health_aggregator(namespace, config) do
    case HealthAggregator.start_link([namespace: namespace, config: config]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, {:health_aggregator_failed, reason}}
    end
  end

  @spec start_rate_limiters(ServiceRegistry.namespace(), map()) :: :ok | {:error, term()}
  defp start_rate_limiters(namespace, config) do
    case TokenBucketLimiter.start_link([namespace: namespace, config: config]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, {:rate_limiter_failed, reason}}
    end
  end

  @spec setup_circuit_breakers(ServiceRegistry.namespace(), map()) :: :ok | {:error, term()}
  defp setup_circuit_breakers(namespace, config) do
    services = [:config_server, :event_store, :telemetry_service]

    Enum.reduce_while(services, :ok, fn service, :ok ->
      case CircuitBreaker.start_link([
        service: service,
        namespace: namespace,
        config: Map.get(config, service, %{})
      ]) do
        {:ok, _pid} -> {:cont, :ok}
        {:error, {:already_started, _pid}} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:circuit_breaker_failed, service, reason}}}
      end
    end)
  end

  @spec setup_connection_pools(ServiceRegistry.namespace(), map()) :: :ok | {:error, term()}
  defp setup_connection_pools(namespace, config) do
    pools = Map.get(config, :pools, [])

    Enum.reduce_while(pools, :ok, fn {pool_name, pool_config}, :ok ->
      connection_spec = %{
        module: pool_config.module,
        options: pool_config.options,
        health_check: pool_config.health_check
      }

      case ConnectionPoolRegistry.register_pool(namespace, pool_name, connection_spec, pool_config.config) do
        {:ok, _pid} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:connection_pool_failed, pool_name, reason}}}
      end
    end)
  end

  @spec check_memory_pressure(ServiceRegistry.namespace()) :: :ok | {:error, term()}
  defp check_memory_pressure(namespace) do
    case MemoryManager.check_pressure(namespace) do
      :critical -> {:error, :memory_pressure_critical}
      _ -> :ok
    end
  end

  @spec check_rate_limit(ServiceRegistry.namespace(), term(), map()) :: :ok | {:error, term()}
  defp check_rate_limit(namespace, rate_key, rate_config) do
    ElixirScope.Foundation.Infrastructure.RateLimiter.check_rate_limit(
      namespace, rate_key, rate_config
    )
  end

  @spec execute_with_circuit_breaker(ServiceRegistry.namespace(), atom(), (-> term())) ::
    {:ok, term()} | {:error, term()}
  defp execute_with_circuit_breaker(namespace, service, operation) do
    CircuitBreaker.execute(namespace, service, operation)
  end

  @spec record_operation_success(ServiceRegistry.namespace(), atom()) :: :ok
  defp record_operation_success(namespace, service) do
    PerformanceMonitor.record_throughput(
      namespace,
      [:foundation, service, :operations],
      1.0,
      %{status: :success}
    )
  end

  @spec record_operation_failure(ServiceRegistry.namespace(), atom(), term()) :: :ok
  defp record_operation_failure(namespace, service, reason) do
    PerformanceMonitor.record_error_rate(
      namespace,
      [:foundation, service, :operations],
      100.0,
      %{status: :error, reason: inspect(reason)}
    )
  end

  @spec determine_overall_infrastructure_status(map(), map()) :: atom()
  defp determine_overall_infrastructure_status(system_health, memory_stats) do
    cond do
      system_health.status == :unhealthy -> :unhealthy
      memory_stats.pressure_level == :critical -> :critical
      system_health.status == :degraded or memory_stats.pressure_level == :high -> :degraded
      true -> :healthy
    end
  end

  @spec get_circuit_breaker_health(ServiceRegistry.namespace()) :: map()
  defp get_circuit_breaker_health(namespace) do
    services = [:config_server, :event_store, :telemetry_service]

    Enum.reduce(services, %{}, fn service, acc ->
      case CircuitBreaker.get_stats(namespace, service) do
        {:ok, stats} -> Map.put(acc, service, stats)
        {:error, _} -> Map.put(acc, service, %{status: :not_available})
      end
    end)
  end

  @spec default_infrastructure_config() :: map()
  defp default_infrastructure_config do
    %{
      memory: %{
        check_interval: 30_000,
        warning_threshold: 0.7,
        critical_threshold: 0.9,
        cleanup_strategies: [
          ElixirScope.Foundation.Infrastructure.MemoryCleanup.EventStoreCleanup,
          ElixirScope.Foundation.Infrastructure.MemoryCleanup.ConfigCacheCleanup,
          ElixirScope.Foundation.Infrastructure.MemoryCleanup.TelemetryCleanup
        ],
        pressure_relief_enabled: true
      },
      performance: %{
        retention_minutes: 60,
        aggregation_interval: 300_000
      },
      health: %{
        check_interval: 60_000,
        deep_check_timeout: 10_000
      },
      rate_limiting: %{
        default_algorithm: :token_bucket,
        cleanup_interval: 600_000
      },
      circuit_breakers: %{
        config_server: %{
          failure_threshold: 5,
          reset_timeout: 30_000,
          call_timeout: 5_000,
          monitor_window: 60_000
        },
        event_store: %{
          failure_threshold: 3,
          reset_timeout: 15_000,
          call_timeout: 3_000,
          monitor_window: 30_000
        },
        telemetry_service: %{
          failure_threshold: 10,
          reset_timeout: 60_000,
          call_timeout: 2_000,
          monitor_window: 120_000
        }
      },
      connection_pools: %{
        pools: [
          database: %{
            module: ElixirScope.Foundation.Infrastructure.DatabaseConnection,
            options: [
              database_url: "postgresql://localhost/elixir_scope",
              timeout: 5000
            ],
            config: %{
              min_size: 2,
              max_size: 10,
              checkout_timeout: 5_000,
              idle_timeout: 300_000,
              max_retries: 3,
              health_check_interval: 60_000
            },
            health_check: fn conn ->
              ElixirScope.Foundation.Infrastructure.DatabaseConnection.ping_connection(conn) == :ok
            end
          }
        ]
      }
    }
  end

  @spec default_rate_config() :: map()
  defp default_rate_config do
    %{
      algorithm: :token_bucket,
      limit: 100,
      window_ms: 60_000,
      burst_limit: 120
    }
  end
end

defmodule ElixirScope.Foundation.Infrastructure.ServiceProtection do
  @moduledoc """
  Mixin module for adding infrastructure protection to Foundation services.

  Provides automatic integration with all infrastructure components:
  - Circuit breaker protection
  - Rate limiting
  - Memory pressure awareness
  - Performance monitoring
  - Health checking
  """

  defmacro __using__(opts) do
    quote do
      import ElixirScope.Foundation.Infrastructure.ServiceProtection

      @infrastructure_namespace Keyword.get(unquote(opts), :namespace, :production)
      @service_name Keyword.get(unquote(opts), :service_name, __MODULE__)
      @rate_config Keyword.get(unquote(opts), :rate_config, %{
        algorithm: :token_bucket,
        limit: 100,
        window_ms: 60_000,
        burst_limit: 120
      })

      @before_compile ElixirScope.Foundation.Infrastructure.ServiceProtection
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def protected_call(operation, args, opts \\ []) do
        ElixirScope.Foundation.Infrastructure.protected_operation(
          @infrastructure_namespace,
          @service_name,
          Keyword.merge([
            rate_key: {@service_name, operation},
            rate_config: @rate_config
          ], opts),
          fn -> apply(__MODULE__, operation, args) end
        )
      end

      def infrastructure_health_check do
        ElixirScope.Foundation.Infrastructure.HealthCheck.deep_health_check(
          @infrastructure_namespace,
          @service_name
        )
      end

      def check_circuit_breaker_status do
        ElixirScope.Foundation.Infrastructure.CircuitBreaker.check_state(
          @infrastructure_namespace,
          @service_name
        )
      end

      def get_performance_metrics do
        ElixirScope.Foundation.Infrastructure.PerformanceMonitor.get_metrics(
          @infrastructure_namespace,
          @service_name,
          :hour,
          :avg
        )
      end
    end
  end

  defmacro with_infrastructure_protection(operation_name, do: block) do
    quote do
      def unquote(operation_name)(args) do
        protected_call(
          unquote(operation_name),
          [args],
          []
        )
      end

      defp unquote(:"#{operation_name}_impl")(args) do
        unquote(block)
      end
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.IntegrationExample do
  @moduledoc """
  Example of how to integrate infrastructure with Foundation services.
  """

  alias ElixirScope.Foundation.{ServiceRegistry}
  alias ElixirScope.Foundation.Infrastructure

  @doc """
  Example: Initialize complete infrastructure for production.
  """
  def setup_production_infrastructure do
    namespace = :production

    case Infrastructure.initialize_infrastructure(namespace) do
      :ok ->
        IO.puts("✅ Infrastructure initialized successfully")
        demonstrate_infrastructure_usage(namespace)
      {:error, reason} ->
        IO.puts("❌ Infrastructure initialization failed: #{inspect(reason)}")
    end
  end

  @doc """
  Example: Demonstrate infrastructure working together.
  """
  def demonstrate_infrastructure_usage(namespace) do
    IO.puts("\n🔧 Demonstrating infrastructure integration...")

    # 1. Check overall infrastructure health
    case Infrastructure.get_infrastructure_health(namespace) do
      {:ok, health} ->
        IO.puts("📊 Infrastructure Status: #{health.overall_status}")
        IO.puts("   Memory Pressure: #{health.memory.pressure_level}")
        IO.puts("   System Health: #{health.system_health.status}")
      {:error, reason} ->
        IO.puts("❌ Health check failed: #{inspect(reason)}")
    end

    # 2. Demonstrate protected operation
    IO.puts("\n🛡️  Testing protected operation...")

    result = Infrastructure.protected_operation(
      namespace,
      :config_server,
      [rate_key: :demo_operation],
      fn ->
        # Simulate some work
        Process.sleep(10)
        {:ok, "Operation completed"}
      end
    )

    case result do
      {:ok, message} -> IO.puts("✅ Protected operation: #{message}")
      {:error, reason} -> IO.puts("❌ Protected operation failed: #{inspect(reason)}")
    end

    # 3. Simulate load and show rate limiting
    IO.puts("\n⚡ Testing rate limiting...")

    Enum.each(1..10, fn i ->
      case Infrastructure.protected_operation(
        namespace,
        :config_server,
        [rate_key: :load_test, rate_config: %{
          algorithm: :token_bucket,
          limit: 5,
          window_ms: 10_000,
          burst_limit: 5
        }],
        fn -> {:ok, "Request #{i}"} end
      ) do
        {:ok, _} -> IO.write("✅")
        {:error, :rate_limited, _} -> IO.write("🚫")
        {:error, _} -> IO.write("❌")
      end
    end)
    IO.puts(" (Rate limiting in action)")

    # 4. Show memory management in action
    IO.puts("\n💾 Testing memory management...")

    # Request cleanup
    Infrastructure.MemoryManager.request_cleanup(namespace, :event_store, [priority: :high])
    IO.puts("✅ Memory cleanup requested")

    # 5. Demonstrate circuit breaker
    IO.puts("\n⚡ Testing circuit breaker...")

    # Simulate failures to trip circuit breaker
    Enum.each(1..3, fn i ->
      Infrastructure.protected_operation(
        namespace,
        :demo_service,
        [],
        fn ->
          # Simulate failure
          {:error, "Simulated failure #{i}"}
        end
      )
    end)

    IO.puts("✅ Circuit breaker demonstration complete")
  end

  @doc """
  Example: Show how to enhance a service with infrastructure protection.
  """
  def demonstrate_service_enhancement do
    defmodule EnhancedConfigServer do
      use ElixirScope.Foundation.Infrastructure.ServiceProtection,
        service_name: :config_server,
        namespace: :production

      # Protected version of config operations
      with_infrastructure_protection :get_config do
        # Original config logic here
        ElixirScope.Foundation.Config.get()
      end

      with_infrastructure_protection :update_config do
        {path, value} = args
        ElixirScope.Foundation.Config.update(path, value)
      end
    end

    IO.puts("✅ Enhanced service created with infrastructure protection")
  end
end
