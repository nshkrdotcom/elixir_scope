# Infrastructure Migration: Files Modified/Discarded + Poolboy Integration

## **Files Status & Actions**

### **🗑️ DISCARDED FILES**
```
rate_limiter.ex                    # Replace with ExRated wrapper
├── TokenBucketLimiter            # ExRated handles this better
├── SlidingWindowLimiter          # ExRated handles this better  
├── FixedWindowLimiter            # ExRated handles this better
└── RateLimitedService macro      # Simplify with ExRated

connection_pool.ex                 # Replace with Poolboy wrapper
├── ConnectionPoolManager         # Poolboy handles this better
├── ConnectionPoolRegistry        # Poolboy handles this better
└── DatabaseConnection behavior   # Convert to Poolboy worker
```

### **✏️ MODIFIED FILES**

#### **infrastructure.ex** - Becomes unified interface
```elixir
# BEFORE (original implementation)
defmodule ElixirScope.Foundation.Infrastructure do
  alias ElixirScope.Foundation.Infrastructure.{
    CircuitBreaker,
    MemoryManager, 
    HealthAggregator,
    PerformanceMonitor,
    TokenBucketLimiter,        # ❌ Remove
    ConnectionPoolRegistry     # ❌ Remove  
  }
  
  defp start_rate_limiters(namespace, config) do
    case TokenBucketLimiter.start_link([namespace: namespace, config: config]) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, {:rate_limiter_failed, reason}}
    end
  end
  
  defp setup_connection_pools(namespace, config) do
    # Custom pool management logic...
  end
end

# AFTER (hybrid approach)  
defmodule ElixirScope.Foundation.Infrastructure do
  @moduledoc """
  Unified infrastructure interface using battle-tested libraries.
  """
  
  alias ElixirScope.Foundation.Infrastructure.{
    CircuitBreaker,           # ✅ Keep (custom)
    MemoryManager,           # ✅ Keep  
    HealthAggregator,        # ✅ Keep
    PerformanceMonitor,      # ✅ Keep
    RateLimiter,            # ✅ New (ExRated wrapper)
    ConnectionPool          # ✅ New (Poolboy wrapper)
  }
  
  def protected_operation(namespace, service, opts, operation) do
    with :ok <- check_rate_limit_hybrid(namespace, opts),
         {:ok, result} <- execute_with_connection_pool_hybrid(namespace, opts, fn ->
           CircuitBreaker.execute(namespace, service, operation)
         end) do
      {:ok, result}
    end
  end
  
  defp check_rate_limit_hybrid(namespace, opts) do
    case Keyword.get(opts, :rate_key) do
      nil -> :ok
      rate_key ->
        rate_config = Keyword.get(opts, :rate_config, default_rate_config())
        RateLimiter.check_rate_limit(namespace, rate_key, rate_config)
    end
  end
  
  defp execute_with_connection_pool_hybrid(namespace, opts, operation) do
    case Keyword.get(opts, :pool_name) do
      nil -> operation.()
      pool_name -> ConnectionPool.with_connection(pool_name, operation)
    end
  end
end
```

#### **circuit_breaker.ex** - Minimal modifications
```elixir
# MOSTLY UNCHANGED - your implementation is sufficient
defmodule ElixirScope.Foundation.Infrastructure.CircuitBreaker do
  # ✅ Keep your existing implementation
  # Minor changes: simplify registry integration
  
  def start_link(opts) do
    service = Keyword.fetch!(opts, :service)
    namespace = Keyword.get(opts, :namespace, :production)
    
    # Simplified registration
    name = {:via, Registry, {ElixirScope.Foundation.Registry, {namespace, :circuit_breaker, service}}}
    GenServer.start_link(__MODULE__, opts, name: name)
  end
end
```

### **📁 NEW FILES**

#### **lib/elixir_scope/foundation/infrastructure/rate_limiter.ex**
```elixir
defmodule ElixirScope.Foundation.Infrastructure.RateLimiter do
  @moduledoc """
  ExRated wrapper providing ElixirScope unified interface.
  """
  
  @spec check_rate_limit(term(), term(), map()) :: :ok | {:error, :rate_limited, integer()}
  def check_rate_limit(namespace, key, config) do
    bucket_name = "#{namespace}_#{key}"
    scale = Map.get(config, :window_ms, 60_000)
    limit = Map.get(config, :limit, 100)
    
    case ExRated.check_rate(bucket_name, scale, limit) do
      {:ok, _count} -> :ok
      {:error, _count} -> 
        retry_after = calculate_retry_after(scale, limit)
        {:error, :rate_limited, retry_after}
    end
  end
  
  defp calculate_retry_after(scale, _limit) do
    # Simple retry calculation - ExRated manages the complex logic
    div(scale, 10)  # Wait 1/10th of window
  end
end
```

## **🎯 Poolboy Integration Illustration**

### **Before: Custom Connection Pool**
```elixir
# connection_pool.ex - 500+ lines of complex pool management
defmodule ElixirScope.Foundation.Infrastructure.ConnectionPoolManager do
  use GenServer
  
  # Complex state management
  @type pool_state :: %{
    connections: [connection_info()],
    available: :queue.queue(),
    checked_out: %{reference() => connection_info()},
    stats: map()
  }
  
  def handle_call(:checkout, {from_pid, _ref}, state) do
    case :queue.out(state.available) do
      {{:value, conn_info}, remaining_queue} ->
        # Complex checkout logic...
        monitor_ref = Process.monitor(from_pid)
        # 50+ lines of connection management
      {:empty, _} when map_size(state.checked_out) < state.config.max_size ->
        # Complex connection creation...
      {:empty, _} ->
        {:reply, {:error, :pool_exhausted}, state}
    end
  end
  
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    # Complex cleanup on process death...
  end
end
```

### **After: Poolboy Integration**
```elixir
# lib/elixir_scope/foundation/infrastructure/connection_pool.ex - ~50 lines
defmodule ElixirScope.Foundation.Infrastructure.ConnectionPool do
  @moduledoc """
  Poolboy wrapper providing ElixirScope unified interface.
  """
  
  def with_connection(pool_name, operation, timeout \\ 5000) do
    :poolboy.transaction(pool_name, operation, timeout)
  end
  
  def with_database_connection(operation) do
    with_connection(:database_pool, fn worker ->
      DatabaseWorker.execute(worker, operation)
    end)
  end
end

# lib/elixir_scope/foundation/infrastructure/database_worker.ex
defmodule ElixirScope.Foundation.Infrastructure.DatabaseWorker do
  @moduledoc """
  Poolboy worker for database connections.
  """
  
  use GenServer
  
  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil)
  end
  
  def execute(worker, operation) do
    GenServer.call(worker, {:execute, operation})
  end
  
  def init(_) do
    {:ok, conn} = MyDB.connect()
    {:ok, %{conn: conn}}
  end
  
  def handle_call({:execute, operation}, _from, %{conn: conn} = state) do
    result = operation.(conn)
    {:reply, result, state}
  end
end
```

### **Application Setup - Poolboy Supervision**
```elixir
# lib/elixir_scope/application.ex
defmodule ElixirScope.Application do
  def start(_type, _args) do
    # Poolboy pools in supervision tree
    poolboy_config = [
      name: {:local, :database_pool},
      worker_module: ElixirScope.Foundation.Infrastructure.DatabaseWorker,
      size: 10,           # Minimum pool size
      max_overflow: 5     # Additional workers for burst traffic
    ]
    
    children = [
      # Foundation services
      ElixirScope.Foundation.Registry,
      ElixirScope.Foundation.Services.ConfigServer,
      
      # Poolboy pools
      :poolboy.child_spec(:database_pool, poolboy_config, []),
      
      # Future AST tool pools
      ast_analyzer_pool_spec(),
      
      # Other infrastructure
      {ElixirScope.Foundation.Infrastructure.MemoryManager, [namespace: :production]},
      {ElixirScope.Foundation.Infrastructure.PerformanceMonitor, [namespace: :production]}
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
  
  defp ast_analyzer_pool_spec do
    :poolboy.child_spec(:ast_analyzer_pool, [
      name: {:local, :ast_analyzer_pool},
      worker_module: ElixirScope.AST.Infrastructure.AnalyzerWorker,
      size: 5,
      max_overflow: 2
    ], [])
  end
end
```

### **Foundation Service Integration**
```elixir
# lib/elixir_scope/foundation/services/config_server.ex
defmodule ElixirScope.Foundation.Services.ConfigServer do
  use GenServer
  
  # BEFORE: Complex custom infrastructure calls
  def update_config_with_protection(namespace, path, value, user_context) do
    with :ok <- check_memory_pressure(namespace),
         :ok <- check_rate_limit(namespace, {:config_update, user_context.user_id}, rate_config()),
         {:ok, result} <- execute_with_circuit_breaker(namespace, :config_server, fn ->
           update_config_impl(path, value)
         end) do
      sync_to_database_with_pool(namespace, path, value)
      {:ok, result}
    end
  end
  
  # AFTER: Clean unified interface
  def update_config_protected(namespace, path, value, user_context) do
    ElixirScope.Foundation.Infrastructure.protected_operation(
      namespace,
      :config_server,
      [
        rate_key: {:config_update, user_context.user_id},
        rate_config: %{limit: 10, window_ms: 60_000},
        pool_name: :database_pool
      ],
      fn ->
        result = update_config_impl(path, value)
        sync_config_to_database(path, value)  # Uses pooled connection automatically
        result
      end
    )
  end
  
  defp sync_config_to_database(path, value) do
    ElixirScope.Foundation.Infrastructure.ConnectionPool.with_database_connection(fn conn ->
      MyDB.insert(conn, "configs", %{path: path, value: value})
    end)
  end
end
```

## **File Count Reduction**

**Before (Custom Implementation):**
- `rate_limiter.ex` - 400+ lines (3 algorithms + middleware)
- `connection_pool.ex` - 500+ lines (manager + registry + worker behavior)
- Total: **900+ lines of complex pool/rate management**

**After (Hybrid Approach):**
- `rate_limiter.ex` - 50 lines (ExRated wrapper)
- `connection_pool.ex` - 30 lines (Poolboy wrapper) 
- `database_worker.ex` - 40 lines (Simple Poolboy worker)
- Total: **120 lines of wrapper code**

**Reduction: 780+ lines eliminated**, replaced with battle-tested libraries and clean wrapper interfaces.

The infrastructure becomes **simpler**, **more reliable**, and **better performing** while maintaining ElixirScope's unified architecture vision.