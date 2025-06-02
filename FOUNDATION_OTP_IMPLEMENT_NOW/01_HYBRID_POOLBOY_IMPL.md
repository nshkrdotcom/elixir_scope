# ElixirScope Foundation Infrastructure: Hybrid Implementation Guide

## Library Selection & Integration Strategy

### **Selected Libraries**
- **ExRated** (Rate Limiting) - 50,000+ ops/sec, battle-tested ETS operations
- **Poolboy** (Connection Pooling) - Production-proven overflow handling, worker strategies
- **Custom Circuit Breaker** - Simple needs, unified with ElixirScope architecture

### **Integration Architecture**

```elixir
defmodule ElixirScope.Foundation.Infrastructure do
  @moduledoc """
  Hybrid infrastructure using battle-tested libraries behind unified interface.
  """

  # Rate Limiting - Delegate to ExRated
  defdelegate check_rate_limit(key, scale, limit), to: ExRated
  
  # Connection Pooling - Delegate to Poolboy  
  defdelegate checkout(pool), to: :poolboy
  defdelegate checkin(pool, worker), to: :poolboy
  
  # Circuit Breaker - Custom implementation
  def execute_with_circuit_breaker(namespace, service, operation) do
    ElixirScope.Foundation.Infrastructure.CircuitBreaker.execute(namespace, service, operation)
  end
  
  # Unified interface for all protection
  def protected_operation(namespace, service, opts, operation) do
    with :ok <- check_rate_limit_unified(opts),
         {:ok, result} <- with_pooled_connection_unified(opts, fn ->
           execute_with_circuit_breaker(namespace, service, operation)
         end) do
      {:ok, result}
    end
  end
end
```

## **ExRated Integration**

### **Installation & Setup**
```elixir
# mix.exs
{:ex_rated, "~> 2.0"}

# config/config.exs
config :ex_rated,
  bucket_time_window: 60_000,  # 1 minute
  bucket_max_size: 100,
  cleanup_rate: 10_000         # 10 seconds
```

### **ElixirScope Rate Limiting Wrapper**
```elixir
defmodule ElixirScope.Foundation.Infrastructure.RateLimiter do
  @moduledoc """
  Unified rate limiting interface using ExRated for performance.
  """
  
  @spec check_rate_limit(ServiceRegistry.namespace(), term(), map()) :: 
    :ok | {:error, :rate_limited, integer()}
  def check_rate_limit(namespace, key, config) do
    # Convert ElixirScope config to ExRated format
    bucket_name = "#{namespace}_#{key}"
    scale = config.window_ms
    limit = config.limit
    
    case ExRated.check_rate(bucket_name, scale, limit) do
      {:ok, _count} -> :ok
      {:error, _count} -> 
        retry_after = calculate_retry_after(scale, limit)
        {:error, :rate_limited, retry_after}
    end
  end
  
  # Foundation service integration
  def protect_config_updates(namespace, user_id, operation) do
    case check_rate_limit(namespace, {:config_update, user_id}, %{
      window_ms: 60_000,
      limit: 10
    }) do
      :ok -> operation.()
      error -> error
    end
  end
  
  # AST API protection (future)
  def protect_ast_parse(namespace, request_key, operation) do
    case check_rate_limit(namespace, {:ast_parse, request_key}, %{
      window_ms: 60_000, 
      limit: 100
    }) do
      :ok -> operation.()
      error -> error
    end
  end
end
```

## **Poolboy Integration**

### **Installation & Setup**
```elixir
# mix.exs
{:poolboy, "~> 1.5"}

# Application supervision tree
def start(_type, _args) do
  poolboy_config = [
    name: {:local, :database_pool},
    worker_module: ElixirScope.Foundation.Infrastructure.DatabaseWorker,
    size: 10,
    max_overflow: 5
  ]
  
  children = [
    :poolboy.child_spec(:database_pool, poolboy_config, [])
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### **ElixirScope Connection Pool Wrapper**
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ConnectionPool do
  @moduledoc """
  Unified connection pooling using Poolboy for reliability.
  """
  
  def with_connection(pool_name, operation, timeout \\ 5000) do
    :poolboy.transaction(pool_name, operation, timeout)
  end
  
  # Foundation database connections
  def with_database_connection(operation) do
    with_connection(:database_pool, fn worker ->
      ElixirScope.Foundation.Infrastructure.DatabaseWorker.execute(worker, operation)
    end)
  end
  
  # Future AST external tool connections
  def with_ast_tool_connection(tool_name, operation) do
    pool_name = :"#{tool_name}_pool"
    with_connection(pool_name, operation)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.DatabaseWorker do
  use GenServer
  
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end
  
  def execute(worker, operation) do
    GenServer.call(worker, {:execute, operation})
  end
  
  def init(_args) do
    # Initialize database connection
    {:ok, conn} = MyDB.connect()
    {:ok, %{conn: conn}}
  end
  
  def handle_call({:execute, operation}, _from, %{conn: conn} = state) do
    result = operation.(conn)
    {:reply, result, state}
  end
end
```

## **Custom Circuit Breaker Implementation**

```elixir
defmodule ElixirScope.Foundation.Infrastructure.CircuitBreaker do
  @moduledoc """
  Simple circuit breaker for Foundation services.
  Focused on ElixirScope's specific needs.
  """
  
  use GenServer
  
  @type state :: :closed | :open | :half_open
  
  def start_link(opts) do
    service = Keyword.fetch!(opts, :service)
    namespace = Keyword.get(opts, :namespace, :production)
    
    name = {:via, Registry, {ElixirScope.Foundation.Registry, {namespace, :circuit_breaker, service}}}
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def execute(namespace, service, operation) do
    case Registry.lookup(ElixirScope.Foundation.Registry, {namespace, :circuit_breaker, service}) do
      [{pid, _}] -> GenServer.call(pid, {:execute, operation})
      [] -> operation.() # No circuit breaker means execute
    end
  end
  
  # Simple state machine - just what ElixirScope needs
  def handle_call({:execute, operation}, _from, %{state: :closed} = state) do
    case safe_execute(operation) do
      {:ok, result} -> 
        {:reply, {:ok, result}, record_success(state)}
      {:error, reason} -> 
        new_state = record_failure(state)
        {:reply, {:error, reason}, maybe_open_circuit(new_state)}
    end
  end
  
  def handle_call({:execute, _}, _from, %{state: :open} = state) do
    if should_try_reset?(state) do
      {:reply, {:error, :circuit_open}, %{state | state: :half_open}}
    else
      {:reply, {:error, :circuit_open}, state}
    end
  end
end
```

## **Unified Service Integration**

### **Enhanced Foundation Services**
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServer do
  use GenServer
  
  alias ElixirScope.Foundation.Infrastructure
  
  # Protected config updates with rate limiting
  def update_config_protected(namespace, path, value, user_context) do
    Infrastructure.RateLimiter.protect_config_updates(
      namespace, 
      user_context.user_id,
      fn -> update_config_impl(path, value) end
    )
  end
  
  # Protected config retrieval with circuit breaker
  def get_config_protected(namespace, path) do
    Infrastructure.CircuitBreaker.execute(namespace, :config_server, fn ->
      get_config_impl(path)
    end)
  end
  
  # Database operations with connection pooling
  def sync_config_to_database(namespace, config_data) do
    Infrastructure.ConnectionPool.with_database_connection(fn conn ->
      MyDB.insert(conn, "configs", config_data)
    end)
  end
end
```

### **Future AST Integration Ready**
```elixir
defmodule ElixirScope.AST.Services.Parser do
  # Rate limiting for AST parsing APIs
  def parse_protected(namespace, code, request_context) do
    Infrastructure.RateLimiter.protect_ast_parse(
      namespace,
      request_context.api_key,
      fn -> parse_impl(code) end
    )
  end
  
  # Connection pooling for external AST tools
  def analyze_with_external_tool(namespace, ast_data, tool_name) do
    Infrastructure.ConnectionPool.with_ast_tool_connection(tool_name, fn conn ->
      ExternalTool.analyze(conn, ast_data)
    end)
  end
end
```

## **Configuration Strategy**

```elixir
# config/config.exs
config :elixir_scope, :infrastructure,
  # ExRated configuration
  rate_limiting: [
    cleanup_rate: 10_000,
    bucket_time_window: 60_000
  ],
  
  # Poolboy pools
  connection_pools: %{
    database: [
      size: 10,
      max_overflow: 5,
      worker_module: ElixirScope.Foundation.Infrastructure.DatabaseWorker
    ],
    # Future AST tool pools
    ast_analyzer: [
      size: 5,
      max_overflow: 2,
      worker_module: ElixirScope.AST.Infrastructure.AnalyzerWorker
    ]
  },
  
  # Circuit breaker settings
  circuit_breakers: %{
    failure_threshold: 5,
    reset_timeout: 30_000
  }
```

## **Testing Strategy**

```elixir
defmodule ElixirScope.Foundation.InfrastructureTest do
  use ExUnit.Case
  
  test "rate limiting protects Foundation services" do
    # Test ExRated integration
    Enum.each(1..15, fn _ ->
      ElixirScope.Foundation.Infrastructure.RateLimiter.protect_config_updates(
        :test, "user123", fn -> :ok end
      )
    end)
    
    # Should be rate limited after 10 calls
    assert {:error, :rate_limited, _} = 
      ElixirScope.Foundation.Infrastructure.RateLimiter.protect_config_updates(
        :test, "user123", fn -> :ok end
      )
  end
  
  test "connection pooling handles burst traffic" do
    # Test Poolboy integration
    tasks = for _ <- 1..20 do
      Task.async(fn ->
        ElixirScope.Foundation.Infrastructure.ConnectionPool.with_database_connection(fn conn ->
          # Simulate work
          Process.sleep(100)
          :ok
        end)
      end)
    end
    
    results = Task.await_many(tasks)
    assert Enum.all?(results, &match?(:ok, &1))
  end
end
```

## **Migration Path**

1. **Week 1**: Replace rate limiting with ExRated integration
2. **Week 2**: Replace connection pooling with Poolboy integration  
3. **Week 3**: Implement simple custom circuit breaker
4. **Week 4**: Unified interface and Foundation service integration

**Result**: Production-ready infrastructure with battle-tested performance where it matters, unified ElixirScope interface, and ready for AST layer integration.