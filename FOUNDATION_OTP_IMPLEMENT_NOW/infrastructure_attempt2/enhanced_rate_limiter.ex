defmodule ElixirScope.Foundation.Infrastructure.EnhancedRateLimiter do
  @moduledoc """
  High-performance rate limiter with ETS optimizations and insights from ExRated.

  Features:
  - Atomic ETS operations for high throughput
  - Multiple algorithms with optimal data structures
  - Hierarchical rate limiting (user -> org -> global)
  - Time-bucketed keys for memory efficiency
  - Configurable persistence with DETS backing
  """

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @type rate_limit_result :: :ok | {:error, :rate_limited, retry_after_ms()}
  @type retry_after_ms :: non_neg_integer()

  @type rate_limit_config :: %{
          algorithm: :token_bucket | :sliding_window | :fixed_window | :adaptive,
          limit: pos_integer(),
          window_ms: pos_integer(),
          burst_limit: pos_integer(),
          # Enhanced configuration
          hierarchy: [rate_limit_scope()],
          persistence: boolean(),
          cleanup_interval: pos_integer()
        }

  @type rate_limit_scope :: %{
          scope: :user | :org | :global,
          identifier: term(),
          limit: pos_integer(),
          window_ms: pos_integer()
        }

  @doc """
  Check rate limit with hierarchical enforcement and atomic operations.
  """
  @spec check_rate_limit(ServiceRegistry.namespace(), term(), rate_limit_config()) ::
          rate_limit_result()
  def check_rate_limit(namespace, key, config) do
    case config.algorithm do
      :token_bucket ->
        AtomicTokenBucketLimiter.check_rate_limit(namespace, key, config)
      :sliding_window ->
        OptimizedSlidingWindowLimiter.check_rate_limit(namespace, key, config)
      :fixed_window ->
        AtomicFixedWindowLimiter.check_rate_limit(namespace, key, config)
      :adaptive ->
        AdaptiveRateLimiter.check_rate_limit(namespace, key, config)
    end
  end

  @doc """
  Check hierarchical rate limits (user -> org -> global).
  """
  @spec check_hierarchical_rate_limit(ServiceRegistry.namespace(), term(), [rate_limit_scope()]) ::
          rate_limit_result()
  def check_hierarchical_rate_limit(namespace, base_key, scopes) do
    now = Utils.monotonic_timestamp()

    Enum.reduce_while(scopes, :ok, fn scope, :ok ->
      hierarchical_key = generate_hierarchical_key(base_key, scope, now)

      case check_single_scope(namespace, hierarchical_key, scope) do
        :ok -> {:cont, :ok}
        {:ok, self()}
  end

  @impl true
  def check_rate_limit(_namespace, key, config) do
    now = Utils.monotonic_timestamp()
    window_start = time_window_start(now, config.window_ms)
    window_key = {key, window_start}

    try do
      # Atomic increment and check in single operation
      case :ets.update_counter(@table_name, window_key, [{2, 1}, {3, 1, 0, 0}]) do
        [new_count, _] when new_count <= config.limit ->
          :ok
        [new_count, _] ->
          retry_after = window_start + config.window_ms - now
          {:error, :rate_limited, retry_after}
      end
    catch
      :error, :badarg ->
        # Window doesn't exist, create it
        :ets.insert(@table_name, {window_key, 1, now})
        :ok
    end
  end

  @impl true
  def reset_rate_limit(_namespace, key) do
    # Delete all windows for this key
    :ets.select_delete(@table_name, [
      {{{key, :"$1"}, :_, :_}, [], [true]}
    ])
    :ok
  end

  @impl true
  def get_rate_limit_status(_namespace, key) do
    now = Utils.monotonic_timestamp()
    window_start = time_window_start(now, 60_000)  # Default 1 minute
    window_key = {key, window_start}

    case :ets.lookup(@table_name, window_key) do
      [] ->
        %{remaining: 100, reset_time: window_start + 60_000, retry_after: 0}
      [{_, count, _}] ->
        %{
          remaining: max(0, 100 - count),
          reset_time: window_start + 60_000,
          retry_after: if(count >= 100, do: window_start + 60_000 - now, else: 0)
        }
    end
  end

  ## Private Functions

  @spec time_window_start(integer(), pos_integer()) :: integer()
  defp time_window_start(timestamp, window_ms) do
    div(timestamp, window_ms) * window_ms
  end
end

defmodule ElixirScope.Foundation.Infrastructure.AdaptiveRateLimiter do
  @moduledoc """
  Adaptive rate limiter that adjusts limits based on system load and performance.
  """

  use GenServer
  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @type adaptive_state :: %{
          base_limit: pos_integer(),
          current_limit: pos_integer(),
          success_rate: float(),
          response_time: float(),
          last_adjustment: integer(),
          adjustment_factor: float()
        }

  ## Public API

  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ServiceRegistry.via_tuple(namespace, :adaptive_rate_limiter)
    GenServer.start_link(__MODULE__, [namespace: namespace], name: name)
  end

  @impl true
  def check_rate_limit(namespace, key, config) do
    case ServiceRegistry.lookup(namespace, :adaptive_rate_limiter) do
      {:ok, pid} -> GenServer.call(pid, {:check_adaptive_limit, key, config})
      {:error, _} ->
        # Fallback to token bucket
        AtomicTokenBucketLimiter.check_rate_limit(namespace, key, config)
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)

    state = %{
      namespace: namespace,
      adaptive_states: %{},
      performance_metrics: %{}
    }

    # Schedule periodic adjustment
    schedule_adjustment(30_000)  # Every 30 seconds

    {:ok, state}
  end

  @impl true
  def handle_call({:check_adaptive_limit, key, config}, _from, state) do
    adaptive_state = get_or_create_adaptive_state(key, config, state.adaptive_states)

    # Use current adjusted limit
    adjusted_config = %{config | limit: adaptive_state.current_limit}

    # Delegate to token bucket with adjusted limit
    result = AtomicTokenBucketLimiter.check_rate_limit(state.namespace, key, adjusted_config)

    # Record request for adaptation
    new_state = record_request_metrics(key, result, state)

    {:reply, result, new_state}
  end

  @impl true
  def handle_info(:adjust_limits, state) do
    new_state = adjust_all_limits(state)
    schedule_adjustment(30_000)
    {:noreply, new_state}
  end

  ## Private Functions

  @spec get_or_create_adaptive_state(term(), map(), map()) :: adaptive_state()
  defp get_or_create_adaptive_state(key, config, adaptive_states) do
    case Map.get(adaptive_states, key) do
      nil ->
        %{
          base_limit: config.limit,
          current_limit: config.limit,
          success_rate: 1.0,
          response_time: 0.0,
          last_adjustment: Utils.monotonic_timestamp(),
          adjustment_factor: 1.0
        }
      state -> state
    end
  end

  @spec record_request_metrics(term(), term(), map()) :: map()
  defp record_request_metrics(key, result, state) do
    # Record success/failure for adaptation
    metrics = Map.get(state.performance_metrics, key, %{success: 0, total: 0, response_times: []})

    updated_metrics = case result do
      :ok ->
        %{metrics | success: metrics.success + 1, total: metrics.total + 1}
      {:error, :rate_limited, _} ->
        %{metrics | total: metrics.total + 1}
      _ ->
        metrics
    end

    %{state | performance_metrics: Map.put(state.performance_metrics, key, updated_metrics)}
  end

  @spec adjust_all_limits(map()) :: map()
  defp adjust_all_limits(state) do
    now = Utils.monotonic_timestamp()

    new_adaptive_states =
      Enum.into(state.adaptive_states, %{}, fn {key, adaptive_state} ->
        metrics = Map.get(state.performance_metrics, key, %{success: 0, total: 0})

        if metrics.total > 10 do  # Minimum sample size
          success_rate = metrics.success / metrics.total
          new_limit = calculate_new_limit(adaptive_state, success_rate)

          updated_state = %{
            adaptive_state |
            current_limit: new_limit,
            success_rate: success_rate,
            last_adjustment: now
          }

          {key, updated_state}
        else
          {key, adaptive_state}
        end
      end)

    # Reset metrics for next period
    %{state | adaptive_states: new_adaptive_states, performance_metrics: %{}}
  end

  @spec calculate_new_limit(adaptive_state(), float()) :: pos_integer()
  defp calculate_new_limit(adaptive_state, success_rate) do
    cond do
      success_rate >= 0.95 ->
        # High success rate, can increase limit
        min(adaptive_state.base_limit * 2, round(adaptive_state.current_limit * 1.1))
      success_rate >= 0.8 ->
        # Good success rate, maintain current limit
        adaptive_state.current_limit
      success_rate >= 0.6 ->
        # Moderate success rate, slight decrease
        max(div(adaptive_state.base_limit, 2), round(adaptive_state.current_limit * 0.9))
      true ->
        # Low success rate, significant decrease
        max(div(adaptive_state.base_limit, 4), round(adaptive_state.current_limit * 0.7))
    end
  end

  @spec schedule_adjustment(pos_integer()) :: reference()
  defp schedule_adjustment(interval) do
    Process.send_after(self(), :adjust_limits, interval)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.HierarchicalRateLimiter do
  @moduledoc """
  Hierarchical rate limiting with multiple scopes (user -> org -> global).
  """

  alias ElixirScope.Foundation.Infrastructure.AtomicTokenBucketLimiter

  @doc """
  Check hierarchical rate limits in order of specificity.
  """
  @spec check_hierarchical_limits(ServiceRegistry.namespace(), term(), [map()]) ::
    :ok | {:error, :rate_limited, non_neg_integer()}
  def check_hierarchical_limits(namespace, base_key, limit_configs) do
    Enum.reduce_while(limit_configs, :ok, fn config, :ok ->
      scoped_key = build_scoped_key(base_key, config.scope, config.identifier)

      case AtomicTokenBucketLimiter.check_rate_limit(namespace, scoped_key, config) do
        :ok -> {:cont, :ok}
        {:error, :rate_limited, retry_after} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Build hierarchical rate limit configuration.
  """
  @spec build_hierarchical_config(term(), map()) :: [map()]
  def build_hierarchical_config(request_context, base_config) do
    [
      # User-level limit (most specific)
      %{
        scope: :user,
        identifier: Map.get(request_context, :user_id),
        limit: base_config.user_limit || base_config.limit,
        window_ms: base_config.window_ms,
        algorithm: base_config.algorithm
      },
      # Organization-level limit (intermediate)
      %{
        scope: :org,
        identifier: Map.get(request_context, :org_id),
        limit: base_config.org_limit || (base_config.limit * 10),
        window_ms: base_config.window_ms,
        algorithm: base_config.algorithm
      },
      # Global limit (broadest)
      %{
        scope: :global,
        identifier: :global,
        limit: base_config.global_limit || (base_config.limit * 100),
        window_ms: base_config.window_ms,
        algorithm: base_config.algorithm
      }
    ]
  end

  ## Private Functions

  @spec build_scoped_key(term(), atom(), term()) :: term()
  defp build_scoped_key(base_key, scope, identifier) do
    {scope, identifier, base_key}
  end
end

defmodule ElixirScope.Foundation.Infrastructure.PersistentRateLimiter do
  @moduledoc """
  Rate limiter with DETS persistence for limit state survival across restarts.
  """

  use GenServer
  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  ## Public API

  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    persistence_file = Keyword.get(opts, :persistence_file, "rate_limits.dets")
    name = ServiceRegistry.via_tuple(namespace, :persistent_rate_limiter)

    GenServer.start_link(__MODULE__, [
      namespace: namespace,
      persistence_file: persistence_file
    ], name: name)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    persistence_file = Keyword.fetch!(opts, :persistence_file)

    # Open DETS file for persistence
    dets_file = String.to_atom("rate_limits_#{namespace}")
    {:ok, dets_table} = :dets.open_file(dets_file, [
      file: String.to_charlist(persistence_file),
      type: :set
    ])

    state = %{
      namespace: namespace,
      dets_table: dets_table,
      memory_table: create_memory_table(namespace)
    }

    # Load existing limits from DETS
    load_limits_from_dets(state)

    # Schedule periodic sync
    schedule_sync(60_000)  # Every minute

    {:ok, state}
  end

  @impl true
  def handle_info(:sync_to_dets, state) do
    sync_memory_to_dets(state)
    schedule_sync(60_000)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Final sync before shutdown
    sync_memory_to_dets(state)
    :dets.close(state.dets_table)
    :ok
  end

  ## Private Functions

  @spec create_memory_table(ServiceRegistry.namespace()) :: atom()
  defp create_memory_table(namespace) do
    table_name = :"persistent_rate_limits_#{namespace}"
    :ets.new(table_name, [
      :named_table,
      :public,
      :set,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
    table_name
  end

  @spec load_limits_from_dets(map()) :: :ok
  defp load_limits_from_dets(state) do
    :dets.traverse(state.dets_table, fn object ->
      :ets.insert(state.memory_table, object)
      :continue
    end)
    :ok
  end

  @spec sync_memory_to_dets(map()) :: :ok
  defp sync_memory_to_dets(state) do
    # Get all ETS entries and sync to DETS
    :ets.foldl(fn object, :ok ->
      :dets.insert(state.dets_table, object)
      :ok
    end, :ok, state.memory_table)

    :dets.sync(state.dets_table)
    :ok
  end

  @spec schedule_sync(pos_integer()) :: reference()
  defp schedule_sync(interval) do
    Process.send_after(self(), :sync_to_dets, interval)
  end
enderror, :rate_limited, retry_after} = error -> {:halt, error}
      end
    end)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.AtomicTokenBucketLimiter do
  @moduledoc """
  Token bucket with atomic ETS operations for maximum performance.
  """

  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter
  use GenServer

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  ## Public API

  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    config = Keyword.get(opts, :config, %{})
    name = ServiceRegistry.via_tuple(namespace, :atomic_token_bucket_limiter)
    GenServer.start_link(__MODULE__, [namespace: namespace, config: config], name: name)
  end

  @impl true
  def check_rate_limit(namespace, key, config) do
    table = get_table_name(namespace)
    now = Utils.monotonic_timestamp()
    bucket_key = generate_bucket_key(key, config, now)

    case atomic_token_check(table, bucket_key, config, now) do
      {:ok, remaining} -> :ok
      {:error, retry_after} -> {:error, :rate_limited, retry_after}
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    config = Keyword.fetch!(opts, :config)

    table_name = get_table_name(namespace)

    # Create ETS table with optimizations from ExRated insights
    :ets.new(table_name, [
      :named_table,
      :public,
      :set,
      {:read_concurrency, true},
      {:write_concurrency, true},
      {:decentralized_counters, true}  # OTP 23+ for better performance
    ])

    state = %{
      namespace: namespace,
      config: config,
      table: table_name
    }

    # Schedule cleanup
    schedule_cleanup(Map.get(config, :cleanup_interval, 300_000))

    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup_old_buckets, state) do
    cleanup_expired_buckets(state.table, state.config)
    schedule_cleanup(Map.get(state.config, :cleanup_interval, 300_000))
    {:noreply, state}
  end

  ## Private Functions

  @spec atomic_token_check(atom(), term(), map(), integer()) ::
    {:ok, non_neg_integer()} | {:error, non_neg_integer()}
  defp atomic_token_check(table, bucket_key, config, now) do
    try do
      # Atomic operation: check and update tokens in single ETS operation
      case :ets.update_counter(table, bucket_key, [
        {2, 0},           # Get current tokens
        {3, 1, 0, now},   # Update last_refill timestamp
        {4, 1}            # Increment access count
      ]) do
        [current_tokens, _, _] ->
          # Calculate tokens to add based on time passed
          [{_, _, last_refill, _}] = :ets.lookup(table, bucket_key)
          time_passed = now - last_refill
          tokens_to_add = calculate_tokens_to_add(time_passed, config)

          # Update tokens atomically
          new_tokens = min(current_tokens + tokens_to_add, config.burst_limit)

          if new_tokens >= 1 do
            :ets.update_element(table, bucket_key, [{2, new_tokens - 1}])
            {:ok, new_tokens - 1}
          else
            retry_after = calculate_retry_after(config)
            {:error, retry_after}
          end
      end
    catch
      :error, :badarg ->
        # Bucket doesn't exist, create it
        initial_tokens = config.burst_limit - 1
        :ets.insert(table, {bucket_key, initial_tokens, now, 1})
        {:ok, initial_tokens}
    end
  end

  @spec generate_bucket_key(term(), map(), integer()) :: term()
  defp generate_bucket_key(key, config, now) do
    # Time-bucketed keys for efficient memory usage (ExRated insight)
    bucket_size = Map.get(config, :bucket_size, 60_000)  # 1 minute buckets
    bucket_number = div(now, bucket_size)
    {bucket_number, key}
  end

  @spec calculate_tokens_to_add(integer(), map()) :: integer()
  defp calculate_tokens_to_add(time_passed, config) do
    refill_rate = Map.get(config, :limit, 100)
    window_ms = Map.get(config, :window_ms, 60_000)
    div(time_passed * refill_rate, window_ms)
  end

  @spec calculate_retry_after(map()) :: non_neg_integer()
  defp calculate_retry_after(config) do
    refill_rate = Map.get(config, :limit, 100)
    window_ms = Map.get(config, :window_ms, 60_000)
    div(window_ms, refill_rate)
  end

  @spec cleanup_expired_buckets(atom(), map()) :: non_neg_integer()
  defp cleanup_expired_buckets(table, config) do
    now = Utils.monotonic_timestamp()
    expiry_time = Map.get(config, :bucket_expiry, 3_600_000)  # 1 hour
    cutoff = now - expiry_time

    # Delete expired buckets
    :ets.select_delete(table, [
      {{:"$1", :_, :"$2", :_}, [{:<, :"$2", cutoff}], [true]}
    ])
  end

  @spec get_table_name(ServiceRegistry.namespace()) :: atom()
  defp get_table_name(namespace) do
    :"rate_limit_#{namespace}"
  end

  @spec schedule_cleanup(pos_integer()) :: reference()
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup_old_buckets, interval)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.OptimizedSlidingWindowLimiter do
  @moduledoc """
  Sliding window limiter with optimized ETS operations and memory management.
  """

  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter

  alias ElixirScope.Foundation.Utils

  # Use ordered_set for efficient range operations
  @table_name :sliding_window_rate_limits

  def start_link(_opts) do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [
          :named_table,
          :public,
          :ordered_set,  # Ordered for efficient range queries
          {:read_concurrency, true},
          {:write_concurrency, true}
        ])
      _ ->
        :ok
    end
    {:ok, self()}
  end

  @impl true
  def check_rate_limit(_namespace, key, config) do
    now = Utils.monotonic_timestamp()
    window_start = now - config.window_ms

    # Atomic cleanup and count in single traversal
    {current_count, cleaned_count} = cleanup_and_count(key, window_start, now)

    if current_count < config.limit do
      # Insert with microsecond precision to avoid collisions
      unique_timestamp = now * 1000 + :rand.uniform(999)
      :ets.insert(@table_name, {{key, unique_timestamp}, true})
      :ok
    else
      retry_after = calculate_sliding_retry_after(key, config, now)
      {:error, :rate_limited, retry_after}
    end
  end

  @impl true
  def reset_rate_limit(_namespace, key) do
    # Delete all entries for this key
    :ets.select_delete(@table_name, [
      {{{key, :"$1"}, :_}, [], [true]}
    ])
    :ok
  end

  @impl true
  def get_rate_limit_status(_namespace, key) do
    now = Utils.monotonic_timestamp()
    window_start = now - 60_000  # Default 1 minute window

    current_count = :ets.select_count(@table_name, [
      {{{key, :"$1"}, :_}, [{:>=, :"$1", window_start}], [true]}
    ])

    %{
      remaining: max(0, 100 - current_count),
      reset_time: now + 60_000,
      retry_after: if(current_count >= 100, do: 1000, else: 0)
    }
  end

  ## Private Functions

  @spec cleanup_and_count(term(), integer(), integer()) :: {integer(), integer()}
  defp cleanup_and_count(key, window_start, now) do
    # Count current requests in window
    current_count = :ets.select_count(@table_name, [
      {{{key, :"$1"}, :_}, [{:>=, :"$1", window_start}], [true]}
    ])

    # Clean up old entries for this key
    cleaned_count = :ets.select_delete(@table_name, [
      {{{key, :"$1"}, :_}, [{:<, :"$1", window_start}], [true]}
    ])

    {current_count, cleaned_count}
  end

  @spec calculate_sliding_retry_after(term(), map(), integer()) :: non_neg_integer()
  defp calculate_sliding_retry_after(key, config, now) do
    window_start = now - config.window_ms

    # Find the oldest request in the current window
    case :ets.select(@table_name, [
           {{{key, :"$1"}, :_}, [{:>=, :"$1", window_start}], [:"$1"]}
         ]) do
      [] ->
        0
      timestamps ->
        oldest = Enum.min(timestamps)
        # Time until oldest request falls outside window
        max(0, config.window_ms - (now - oldest))
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.AtomicFixedWindowLimiter do
  @moduledoc """
  Fixed window limiter with atomic counters and efficient memory usage.
  """

  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter

  alias ElixirScope.Foundation.Utils

  @table_name :fixed_window_rate_limits

  def start_link(_opts) do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [
          :named_table,
          :public,
          :set,
          {:read_concurrency, true},
          {:write_concurrency, true},
          {:decentralized_counters, true}
        ])
      _ ->
        :ok
    end
    {:
