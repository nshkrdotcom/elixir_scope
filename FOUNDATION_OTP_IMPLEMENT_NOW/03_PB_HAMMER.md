# ElixirScope Hybrid Infrastructure: Poolboy + Hammer Implementation

## **Revised Library Selection**

### **Selected Libraries**
- **Hammer** (Rate Limiting) - Modern, pluggable backends, multiple algorithms
- **Poolboy** (Connection Pooling) - Production-proven overflow handling, worker strategies  
- **Custom Circuit Breaker** - Simple needs, unified with ElixirScope architecture

### **Why Hammer > ExRated**
- **Modern Architecture**: Pluggable backends (ETS, Redis, Mnesia)
- **Multiple Algorithms**: Fixed window, sliding window, token bucket, leaky bucket
- **Better Performance**: Atomic operations, optimized for high throughput
- **Active Development**: ExRated successor with ongoing improvements
- **Distributed Ready**: Built-in support for multi-node scenarios

## **Dependencies & Setup**

### **mix.exs**
```elixir
defp deps do
  [
    # Rate limiting - modern replacement for ExRated
    {:hammer, "~> 7.0"},
    
    # Connection pooling - battle-tested
    {:poolboy, "~> 1.5.2"},
    
    # ElixirScope core
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.2"},
    
    # Development/testing
    {:benchee, "~> 1.1", only: [:dev, :test]},
    {:observer_cli, "~> 1.7", only: :dev}
  ]
end
```

### **Application Configuration**
```elixir
# config/config.exs
config :elixir_scope, :infrastructure,
  # Hammer rate limiting
  rate_limiting: [
    backend: :ets,  # or :redis for distributed
    algorithm: :token_bucket,  # default algorithm
    cleanup_interval: 30_000
  ],
  
  # Poolboy connection pools
  connection_pools: %{
    database: [
      size: 10,
      max_overflow: 5,
      worker_module: ElixirScope.Foundation.Infrastructure.DatabaseWorker
    ],
    # Future AST external tools
    ast_analyzer: [
      size: 5, 
      max_overflow: 3,
      worker_module: ElixirScope.AST.Infrastructure.AnalyzerWorker
    ]
  }
```

## **Files Status & Implementation**

### **🗑️ DISCARDED FILES**
```
rate_limiter.ex                    # Replace with Hammer wrapper
├── TokenBucketLimiter            # Hammer.ETS.TokenBucket
├── SlidingWindowLimiter          # Hammer.ETS.SlidingWindow  
├── FixedWindowLimiter            # Hammer.ETS.FixWindow
└── RateLimitedService macro      # Simplify with Hammer

connection_pool.ex                 # Replace with Poolboy wrapper
├── ConnectionPoolManager         # Poolboy handles this
├── ConnectionPoolRegistry        # Poolboy handles this
└── DatabaseConnection behavior   # Convert to Poolboy worker
```

### **📁 NEW IMPLEMENTATION FILES**

#### **lib/elixir_scope/foundation/infrastructure/rate_limiter.ex**
```elixir
defmodule ElixirScope.Foundation.Infrastructure.RateLimiter do
  @moduledoc """
  Hammer-based rate limiting with ElixirScope unified interface.
  Provides multiple algorithms and pluggable backends.
  """
  
  use Hammer, backend: :ets
  
  @type rate_limit_result :: :ok | {:error, :rate_limited, non_neg_integer()}
  @type algorithm :: :fixed_window | :sliding_window | :token_bucket | :leaky_bucket
  
  @doc """
  Check rate limit using specified algorithm and configuration.
  """
  @spec check_rate_limit(term(), term(), map()) :: rate_limit_result()
  def check_rate_limit(namespace, key, config) do
    # Build scoped key
    scoped_key = build_key(namespace, key)
    
    # Extract config
    scale = Map.get(config, :window_ms, 60_000)
    limit = Map.get(config, :limit, 100)
    algorithm = Map.get(config, :algorithm, :token_bucket)
    
    # Use appropriate algorithm
    case algorithm do
      :fixed_window -> check_fixed_window(scoped_key, scale, limit)
      :sliding_window -> check_sliding_window(scoped_key, scale, limit)
      :token_bucket -> check_token_bucket(scoped_key, scale, limit, config)
      :leaky_bucket -> check_leaky_bucket(scoped_key, scale, limit, config)
    end
  end
  
  # Foundation service protection patterns
  def protect_config_updates(namespace, user_id, operation) do
    case check_rate_limit(namespace, {:config_update, user_id}, %{
      algorithm: :token_bucket,
      limit: 10,
      window_ms: 60_000,
      burst_limit: 15  # Allow small bursts
    }) do
      :ok -> operation.()
      error -> error
    end
  end
  
  def protect_event_storage(namespace, source_id, operation) do
    case check_rate_limit(namespace, {:event_store, source_id}, %{
      algorithm: :leaky_bucket,  # Smooth event flow
      limit: 100,
      window_ms: 60_000
    }) do
      :ok -> operation.()
      error -> error
    end
  end
  
  # Future AST API protection
  def protect_ast_parsing(namespace, request_id, operation) do
    case check_rate_limit(namespace, {:ast_parse, request_id}, %{
      algorithm: :sliding_window,  # Precise control for expensive operations
      limit: 50,
      window_ms: 60_000
    }) do
      :ok -> operation.()
      error -> error
    end
  end
  
  ## Private Algorithm Implementations
  
  defp check_fixed_window(key, scale, limit) do
    case hit(key, scale, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, :rate_limited, retry_after}
    end
  end
  
  defp check_sliding_window(key, scale, limit) do
    # Use Hammer's sliding window implementation
    backend_module = Hammer.ETS.SlidingWindow
    case backend_module.hit(key, scale, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, :rate_limited, retry_after}
    end
  end
  
  defp check_token_bucket(key, scale, limit, config) do
    burst_limit = Map.get(config, :burst_limit, limit)
    backend_module = Hammer.ETS.TokenBucket
    
    case backend_module.hit(key, scale, limit, burst_limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, :rate_limited, retry_after}
    end
  end
  
  defp check_leaky_bucket(key, scale, limit, config) do
    leak_rate = Map.get(config, :leak_rate, div(limit, 10))  # Default leak rate
    backend_module = Hammer.ETS.LeakyBucket
    
    case backend_module.hit(key, scale, limit, leak_rate) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, :rate_limited, retry_after}
    end
  end
  
  defp build_key(namespace, key) do
    "#{namespace}:#{inspect(key)}"
  end
end
```

#### **lib/elixir_scope/foundation/infrastructure/connection_pool.ex**
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ConnectionPool do
  @moduledoc """
  Poolboy-based connection pooling with ElixirScope unified interface.
  """
  
  @doc """
  Execute operation with pooled connection.
  """
  @spec with_connection(atom(), (term() -> term()), pos_integer()) :: 
    {:ok, term()} | {:error, term()}
  def with_connection(pool_name, operation, timeout \\ 5_000) do
    try do
      :poolboy.transaction(pool_name, operation, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :pool_timeout}
      :exit, reason -> {:error, {:pool_error, reason}}
    end
  end
  
  @doc """
  Get pooled database connection for Foundation services.
  """
  def with_database_connection(operation) do
    with_connection(:database_pool, fn worker ->
      DatabaseWorker.execute(worker, operation)
    end)
  end
  
  @doc """
  Future: Get pooled connection to external AST analysis tools.
  """
  def with_ast_analyzer_connection(operation) do
    with_connection(:ast_analyzer_pool, fn worker ->
      ASTAnalyzerWorker.execute(worker, operation)
    end)
  end
  
  @doc """
  Get pool statistics for monitoring.
  """
  @spec get_pool_stats(atom()) :: map()
  def get_pool_stats(pool_name) do
    case :poolboy.status(pool_name) do
      {state_name, total_processes, active_processes, available_processes} ->
        %{
          pool_name: pool_name,
          state: state_name,
          total: total_processes,
          active: active_processes,
          available: available_processes,
          utilization: active_processes / total_processes
        }
    rescue
      _ -> %{pool_name: pool_name, error: :unavailable}
    end
  end
end
```

#### **lib/elixir_scope/foundation/infrastructure/database_worker.ex**
```elixir
defmodule ElixirScope.Foundation.Infrastructure.DatabaseWorker do
  @moduledoc """
  Poolboy worker for database connections.
  """
  
  use GenServer
  require Logger
  
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end
  
  def execute(worker, operation) when is_function(operation, 1) do
    GenServer.call(worker, {:execute, operation})
  end
  
  @impl true
  def init(args) do
    database_url = Keyword.get(args, :database_url, "postgresql://localhost/elixir_scope")
    
    case establish_connection(database_url) do
      {:ok, conn} ->
        Logger.debug("Database worker started with connection")
        {:ok, %{conn: conn, database_url: database_url}}
      
      {:error, reason} ->
        Logger.error("Failed to establish database connection: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:execute, operation}, _from, %{conn: conn} = state) do
    try do
      result = operation.(conn)
      {:reply, {:ok, result}, state}
    rescue
      error ->
        Logger.warning("Database operation failed: #{inspect(error)}")
        
        # Attempt to reconnect if connection is broken
        case check_connection_health(conn) do
          :ok -> 
            {:reply, {:error, error}, state}
          :error ->
            case reconnect(state) do
              {:ok, new_state} -> 
                {:reply, {:error, :connection_reset}, new_state}
              {:error, _} ->
                {:reply, {:error, error}, state}
            end
        end
    end
  end
  
  @impl true
  def terminate(_reason, %{conn: conn}) do
    close_connection(conn)
    :ok
  end
  
  ## Private Functions
  
  defp establish_connection(database_url) do
    # Replace with actual database driver
    # {:ok, conn} = MyDB.connect(database_url)
    {:ok, %{url: database_url, pid: self()}}
  end
  
  defp close_connection(_conn) do
    # MyDB.disconnect(conn)
    :ok
  end
  
  defp check_connection_health(_conn) do
    # MyDB.ping(conn)
    :ok
  end
  
  defp reconnect(%{database_url: url} = state) do
    case establish_connection(url) do
      {:ok, new_conn} ->
        {:ok, %{state | conn: new_conn}}
      error ->
        error
    end
  end
end
```

### **✏️ MODIFIED FILES**

#### **infrastructure.ex** - Unified Interface
```elixir
defmodule ElixirScope.Foundation.Infrastructure do
  @moduledoc """
  Unified infrastructure interface using Hammer + Poolboy.
  """
  
  alias ElixirScope.Foundation.Infrastructure.{
    CircuitBreaker,           # ✅ Keep (custom)
    MemoryManager,           # ✅ Keep  
    HealthAggregator,        # ✅ Keep
    PerformanceMonitor,      # ✅ Keep
    RateLimiter,            # ✅ New (Hammer wrapper)
    ConnectionPool          # ✅ New (Poolboy wrapper)
  }
  
  @doc """
  Execute operation with comprehensive infrastructure protection.
  """
  @spec protected_operation(term(), atom(), keyword(), (-> term())) ::
    {:ok, term()} | {:error, term()}
  def protected_operation(namespace, service, opts, operation) do
    with :ok <- check_memory_pressure(namespace),
         :ok <- check_rate_limit_if_configured(namespace, opts),
         {:ok, result} <- execute_with_pooled_connection_if_configured(opts, fn ->
           CircuitBreaker.execute(namespace, service, operation)
         end) do
      record_operation_success(namespace, service)
      {:ok, result}
    else
      {:error, reason} = error ->
        record_operation_failure(namespace, service, reason)
        error
    end
  end
  
  ## Enhanced Service Protection Patterns
  
  def protect_config_operation(namespace, operation_type, user_context, operation) do
    protected_operation(
      namespace,
      :config_server,
      [
        rate_key: {operation_type, user_context.user_id},
        rate_config: config_rate_limit_config(operation_type),
        pool_name: :database_pool
      ],
      operation
    )
  end
  
  def protect_event_operation(namespace, source_id, operation) do
    protected_operation(
      namespace,
      :event_store,
      [
        rate_key: {:event_store, source_id},
        rate_config: event_rate_limit_config(),
        # Events don't typically need pooled connections
      ],
      operation
    )
  end
  
  # Future AST protection
  def protect_ast_operation(namespace, request_context, operation) do
    protected_operation(
      namespace,
      :ast_parser,
      [
        rate_key: {:ast_parse, request_context.api_key},
        rate_config: ast_rate_limit_config(),
        pool_name: :ast_analyzer_pool
      ],
      operation
    )
  end
  
  ## Private Implementation
  
  defp check_rate_limit_if_configured(namespace, opts) do
    case {Keyword.get(opts, :rate_key), Keyword.get(opts, :rate_config)} do
      {nil, _} -> :ok
      {_, nil} -> :ok
      {rate_key, rate_config} ->
        RateLimiter.check_rate_limit(namespace, rate_key, rate_config)
    end
  end
  
  defp execute_with_pooled_connection_if_configured(opts, operation) do
    case Keyword.get(opts, :pool_name) do
      nil -> operation.()
      pool_name -> 
        ConnectionPool.with_connection(pool_name, fn _worker ->
          operation.()
        end)
    end
  end
  
  defp config_rate_limit_config(:update) do
    %{algorithm: :token_bucket, limit: 10, window_ms: 60_000, burst_limit: 15}
  end
  
  defp config_rate_limit_config(:get) do
    %{algorithm: :fixed_window, limit: 1000, window_ms: 60_000}
  end
  
  defp event_rate_limit_config do
    %{algorithm: :leaky_bucket, limit: 100, window_ms: 60_000, leak_rate: 10}
  end
  
  defp ast_rate_limit_config do
    %{algorithm: :sliding_window, limit: 50, window_ms: 60_000}
  end
end
```

## **Application Supervision Setup**

### **lib/elixir_scope/application.ex**
```elixir
defmodule ElixirScope.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Core Foundation
      ElixirScope.Foundation.Registry,
      
      # Hammer rate limiter
      {ElixirScope.Foundation.Infrastructure.RateLimiter, []},
      
      # Poolboy connection pools
      database_pool_spec(),
      ast_analyzer_pool_spec(),
      
      # Foundation services
      {ElixirScope.Foundation.Services.ConfigServer, [namespace: :production]},
      {ElixirScope.Foundation.Services.EventStore, [namespace: :production]},
      
      # Infrastructure monitoring
      {ElixirScope.Foundation.Infrastructure.MemoryManager, [namespace: :production]},
      {ElixirScope.Foundation.Infrastructure.PerformanceMonitor, [namespace: :production]},
    ]
    
    opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp database_pool_spec do
    poolboy_config = [
      name: {:local, :database_pool},
      worker_module: ElixirScope.Foundation.Infrastructure.DatabaseWorker,
      size: 10,
      max_overflow: 5
    ]
    
    worker_args = [
      database_url: Application.get_env(:elixir_scope, :database_url)
    ]
    
    :poolboy.child_spec(:database_pool, poolboy_config, worker_args)
  end
  
  defp ast_analyzer_pool_spec do
    poolboy_config = [
      name: {:local, :ast_analyzer_pool},
      worker_module: ElixirScope.AST.Infrastructure.AnalyzerWorker,
      size: 5,
      max_overflow: 3
    ]
    
    :poolboy.child_spec(:ast_analyzer_pool, poolboy_config, [])
  end
end
```

## **Foundation Service Integration Examples**

### **Enhanced ConfigServer**
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServer do
  use GenServer
  
  def update_config_protected(namespace, path, value, user_context) do
    ElixirScope.Foundation.Infrastructure.protect_config_operation(
      namespace,
      :update,
      user_context,
      fn ->
        # The actual operation - can use pooled DB connection automatically
        result = update_config_impl(path, value)
        persist_config_change(path, value, user_context)
        result
      end
    )
  end
  
  def get_config_protected(namespace, path, user_context) do
    ElixirScope.Foundation.Infrastructure.protect_config_operation(
      namespace,
      :get,
      user_context,
      fn -> get_config_impl(path) end
    )
  end
  
  defp persist_config_change(path, value, user_context) do
    # This automatically uses the pooled database connection
    ElixirScope.Foundation.Infrastructure.ConnectionPool.with_database_connection(fn conn ->
      insert_config_audit(conn, path, value, user_context)
    end)
  end
end
```

## **Performance Characteristics**

### **Hammer Performance Benefits**
- **ETS Backend**: 100,000+ ops/sec for simple algorithms
- **Atomic Operations**: Lock-free concurrent access
- **Memory Efficient**: Time-based cleanup, configurable retention
- **Multiple Algorithms**: Choose optimal algorithm per use case

### **Algorithm Selection Guide for ElixirScope**
```elixir
# Foundation Services
config_updates: :token_bucket,      # Allow bursts, smooth average
event_storage: :leaky_bucket,       # Smooth flow, prevent spikes
telemetry: :fixed_window,          # Simple, low overhead

# Future AST Services  
ast_parsing: :sliding_window,       # Precise control for expensive ops
ast_analysis: :token_bucket,        # Allow analytical bursts
external_tools: :leaky_bucket,      # Steady flow to external APIs
```

### **Monitoring & Observability**
```elixir
# Built-in monitoring
{:ok, stats} = ElixirScope.Foundation.Infrastructure.ConnectionPool.get_pool_stats(:database_pool)
# %{pool_name: :database_pool, total: 10, active: 3, available: 7, utilization: 0.3}

# Hammer provides built-in metrics
{:ok, count} = ElixirScope.Foundation.Infrastructure.RateLimiter.inspect("production:config_update:user123")
# Current bucket state for monitoring

# Integration with Foundation performance monitoring
ElixirScope.Foundation.Infrastructure.PerformanceMonitor.record_latency(
  :production, 
  [:infrastructure, :rate_limit, :check], 
  duration_us
)
```

This hybrid approach gives you **battle-tested performance** with **ElixirScope's unified architecture**, ready for both current Foundation needs and future AST layer requirements.