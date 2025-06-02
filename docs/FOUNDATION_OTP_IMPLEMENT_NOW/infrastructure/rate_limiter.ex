defmodule ElixirScope.Foundation.Infrastructure.RateLimiter do
  @moduledoc """
  Rate limiting framework with multiple algorithms.

  Essential for AST layer APIs that will need protection from abuse.
  Provides flexible rate limiting with token bucket, sliding window, and fixed window algorithms.

  ## Algorithms
  - :token_bucket - Allows bursts up to bucket capacity
  - :sliding_window - Rolling time window with precise rate limiting
  - :fixed_window - Fixed time periods with reset boundaries
  """

  @type t :: rate_limit_config()

  @type rate_limit_result :: :ok | {:error, :rate_limited, retry_after_ms()}
  @type retry_after_ms :: non_neg_integer()
  @type rate_limit_config :: %{
          algorithm: :token_bucket | :sliding_window | :fixed_window,
          limit: pos_integer(),
          window_ms: pos_integer(),
          burst_limit: pos_integer()
        }
  @type rate_limit_status :: %{
          remaining: non_neg_integer(),
          reset_time: integer(),
          retry_after: non_neg_integer()
        }

  @callback check_rate_limit(key :: term(), config :: rate_limit_config()) :: rate_limit_result()
  @callback reset_rate_limit(key :: term()) :: :ok
  @callback get_rate_limit_status(key :: term()) :: rate_limit_status()

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @doc """
  Check rate limit for a key using specified algorithm.
  """
  @spec check_rate_limit(ServiceRegistry.namespace(), term(), rate_limit_config()) ::
          rate_limit_result()
  def check_rate_limit(namespace, key, config) do
    case config.algorithm do
      :token_bucket ->
        TokenBucketLimiter.check_rate_limit(namespace, key, config)

      :sliding_window ->
        SlidingWindowLimiter.check_rate_limit(namespace, key, config)

      :fixed_window ->
        FixedWindowLimiter.check_rate_limit(namespace, key, config)
    end
  end

  @doc """
  Reset rate limit for a key.
  """
  @spec reset_rate_limit(ServiceRegistry.namespace(), term(), atom()) :: :ok
  def reset_rate_limit(namespace, key, algorithm) do
    case algorithm do
      :token_bucket -> TokenBucketLimiter.reset_rate_limit(namespace, key)
      :sliding_window -> SlidingWindowLimiter.reset_rate_limit(namespace, key)
      :fixed_window -> FixedWindowLimiter.reset_rate_limit(namespace, key)
    end
  end

  @doc """
  Get rate limit status for a key.
  """
  @spec get_rate_limit_status(ServiceRegistry.namespace(), term(), atom()) :: rate_limit_status()
  def get_rate_limit_status(namespace, key, algorithm) do
    case algorithm do
      :token_bucket -> TokenBucketLimiter.get_rate_limit_status(namespace, key)
      :sliding_window -> SlidingWindowLimiter.get_rate_limit_status(namespace, key)
      :fixed_window -> FixedWindowLimiter.get_rate_limit_status(namespace, key)
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.TokenBucketLimiter do
  @moduledoc """
  Token bucket rate limiting implementation.

  Allows bursts up to bucket capacity with steady refill rate.
  Good for APIs that need to handle occasional traffic spikes.
  """

  use GenServer
  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @type bucket_state :: %{
          tokens: non_neg_integer(),
          last_refill: integer(),
          capacity: pos_integer(),
          refill_rate: pos_integer()
        }

  ## Public API

  @doc """
  Start token bucket limiter for a namespace.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ServiceRegistry.via_tuple(namespace, :token_bucket_limiter)
    GenServer.start_link(__MODULE__, [namespace: namespace], name: name)
  end

  @impl true
  def check_rate_limit(namespace, key, config) do
    case ServiceRegistry.lookup(namespace, :token_bucket_limiter) do
      {:ok, pid} -> GenServer.call(pid, {:check_tokens, key, config})
      # No limiter means allow
      {:error, _} -> :ok
    end
  end

  @impl true
  def reset_rate_limit(namespace, key) do
    case ServiceRegistry.lookup(namespace, :token_bucket_limiter) do
      {:ok, pid} -> GenServer.call(pid, {:reset_bucket, key})
      {:error, _} -> :ok
    end
  end

  @impl true
  def get_rate_limit_status(namespace, key) do
    case ServiceRegistry.lookup(namespace, :token_bucket_limiter) do
      {:ok, pid} -> GenServer.call(pid, {:get_status, key})
      {:error, _} -> %{remaining: 1000, reset_time: 0, retry_after: 0}
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)

    state = %{
      namespace: namespace,
      buckets: %{}
    }

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:check_tokens, key, config}, _from, state) do
    bucket = get_or_create_bucket(key, config, state.buckets)
    updated_bucket = refill_tokens(bucket, config)

    case updated_bucket.tokens >= 1 do
      true ->
        new_bucket = %{updated_bucket | tokens: updated_bucket.tokens - 1}
        new_buckets = Map.put(state.buckets, key, new_bucket)
        {:reply, :ok, %{state | buckets: new_buckets}}

      false ->
        retry_after = calculate_retry_after(updated_bucket, config)
        new_buckets = Map.put(state.buckets, key, updated_bucket)
        {:reply, {:error, :rate_limited, retry_after}, %{state | buckets: new_buckets}}
    end
  end

  def handle_call({:reset_bucket, key}, _from, state) do
    new_buckets = Map.delete(state.buckets, key)
    {:reply, :ok, %{state | buckets: new_buckets}}
  end

  def handle_call({:get_status, key}, _from, state) do
    case Map.get(state.buckets, key) do
      nil ->
        {:reply, %{remaining: 1000, reset_time: 0, retry_after: 0}, state}

      bucket ->
        status = %{
          remaining: bucket.tokens,
          # Next refill
          reset_time: bucket.last_refill + 1000,
          retry_after: if(bucket.tokens == 0, do: 1000, else: 0)
        }

        {:reply, status, state}
    end
  end

  @impl true
  def handle_info(:cleanup_old_buckets, state) do
    now = Utils.monotonic_timestamp()
    # Remove buckets older than 1 hour
    cutoff = now - 3_600_000

    new_buckets =
      state.buckets
      |> Enum.filter(fn {_key, bucket} -> bucket.last_refill > cutoff end)
      |> Map.new()

    schedule_cleanup()
    {:noreply, %{state | buckets: new_buckets}}
  end

  ## Private Functions

  @spec get_or_create_bucket(term(), map(), map()) :: bucket_state()
  defp get_or_create_bucket(key, config, buckets) do
    case Map.get(buckets, key) do
      nil ->
        %{
          tokens: config.burst_limit,
          last_refill: Utils.monotonic_timestamp(),
          capacity: config.burst_limit,
          refill_rate: config.limit
        }

      bucket ->
        bucket
    end
  end

  @spec refill_tokens(bucket_state(), map()) :: bucket_state()
  defp refill_tokens(bucket, config) do
    now = Utils.monotonic_timestamp()
    time_passed = now - bucket.last_refill

    # Calculate tokens to add based on time passed
    tokens_to_add = div(time_passed * bucket.refill_rate, config.window_ms)
    new_tokens = min(bucket.tokens + tokens_to_add, bucket.capacity)

    %{bucket | tokens: new_tokens, last_refill: now}
  end

  @spec calculate_retry_after(bucket_state(), map()) :: non_neg_integer()
  defp calculate_retry_after(bucket, config) do
    # Time needed to refill one token
    div(config.window_ms, bucket.refill_rate)
  end

  @spec schedule_cleanup() :: reference()
  defp schedule_cleanup do
    # 10 minutes
    Process.send_after(self(), :cleanup_old_buckets, 600_000)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.SlidingWindowLimiter do
  @moduledoc """
  Sliding window rate limiting implementation.

  Provides precise rate limiting with a rolling time window.
  More memory intensive but offers exact rate control.
  """

  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter

  alias ElixirScope.Foundation.Utils

  @table_name :sliding_window_rate_limits

  def start_link(_opts) do
    # Create ETS table for sliding window tracking
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:public, :named_table, :bag])

      _ ->
        :ok
    end

    {:ok, self()}
  end

  @impl true
  def check_rate_limit(_namespace, key, config) do
    now = Utils.monotonic_timestamp()
    window_start = now - config.window_ms

    # Clean old entries
    :ets.select_delete(@table_name, [
      {{key, :"$1", :_}, [{:<, :"$1", window_start}], [true]}
    ])

    # Count current window requests
    current_count =
      :ets.select_count(@table_name, [
        {{key, :"$1", :_}, [{:>=, :"$1", window_start}], [true]}
      ])

    case current_count < config.limit do
      true ->
        :ets.insert(@table_name, {key, now, true})
        :ok

      false ->
        retry_after = calculate_sliding_retry_after(key, config)
        {:error, :rate_limited, retry_after}
    end
  end

  @impl true
  def reset_rate_limit(_namespace, key) do
    :ets.delete(@table_name, key)
    :ok
  end

  @impl true
  def get_rate_limit_status(_namespace, key) do
    now = Utils.monotonic_timestamp()
    # Default 1 minute window
    window_start = now - 60_000

    current_count =
      :ets.select_count(@table_name, [
        {{key, :"$1", :_}, [{:>=, :"$1", window_start}], [true]}
      ])

    %{
      # Default limit 100
      remaining: max(0, 100 - current_count),
      reset_time: now + 60_000,
      retry_after: if(current_count >= 100, do: 1000, else: 0)
    }
  end

  @spec calculate_sliding_retry_after(term(), map()) :: non_neg_integer()
  defp calculate_sliding_retry_after(key, config) do
    now = Utils.monotonic_timestamp()
    window_start = now - config.window_ms

    # Find the oldest request in the window
    case :ets.select(@table_name, [
           {{key, :"$1", :_}, [{:>=, :"$1", window_start}], [:"$1"]}
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

defmodule ElixirScope.Foundation.Infrastructure.FixedWindowLimiter do
  @moduledoc """
  Fixed window rate limiting implementation.

  Simple and memory efficient, resets at fixed intervals.
  May allow bursts at window boundaries but very predictable.
  """

  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter

  alias ElixirScope.Foundation.Utils

  @table_name :fixed_window_rate_limits

  def start_link(_opts) do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:public, :named_table, :set])

      _ ->
        :ok
    end

    {:ok, self()}
  end

  @impl true
  def check_rate_limit(_namespace, key, config) do
    now = Utils.monotonic_timestamp()
    window_start = div(now, config.window_ms) * config.window_ms
    window_key = {key, window_start}

    case :ets.lookup(@table_name, window_key) do
      [] ->
        :ets.insert(@table_name, {window_key, 1})
        :ok

      [{_, count}] when count < config.limit ->
        :ets.update_counter(@table_name, window_key, 1)
        :ok

      [{_, _count}] ->
        retry_after = window_start + config.window_ms - now
        {:error, :rate_limited, retry_after}
    end
  end

  @impl true
  def reset_rate_limit(_namespace, key) do
    # Delete all windows for this key
    :ets.match_delete(@table_name, {{key, :_}, :_})
    :ok
  end

  @impl true
  def get_rate_limit_status(_namespace, key) do
    now = Utils.monotonic_timestamp()
    # Default 1 minute window
    window_start = div(now, 60_000) * 60_000
    window_key = {key, window_start}

    case :ets.lookup(@table_name, window_key) do
      [] ->
        %{remaining: 100, reset_time: window_start + 60_000, retry_after: 0}

      [{_, count}] ->
        %{
          remaining: max(0, 100 - count),
          reset_time: window_start + 60_000,
          retry_after: if(count >= 100, do: window_start + 60_000 - now, else: 0)
        }
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.RateLimitedService do
  @moduledoc """
  Macro for adding rate limiting to service functions.
  """

  defmacro __using__(opts) do
    quote do
      import ElixirScope.Foundation.Infrastructure.RateLimitedService
      @rate_limit_config Keyword.get(unquote(opts), :rate_limit, %{})
      @rate_limit_namespace Keyword.get(unquote(opts), :namespace, :production)
    end
  end

  defmacro rate_limited(function_name, rate_config, do: block) do
    quote do
      def unquote(function_name)(args) do
        rate_key = generate_rate_key(unquote(function_name), args)

        case ElixirScope.Foundation.Infrastructure.RateLimiter.check_rate_limit(
               @rate_limit_namespace,
               rate_key,
               unquote(rate_config)
             ) do
          :ok ->
            unquote(block)

          {:error, :rate_limited, retry_after} ->
            ElixirScope.Foundation.Telemetry.emit_counter(
              [:foundation, :rate_limit, :rejected],
              %{function: unquote(function_name), retry_after: retry_after}
            )

            {:error, create_rate_limited_error(retry_after)}
        end
      end

      defp generate_rate_key(function_name, args) do
        # Simple key generation - can be customized per service
        {__MODULE__, function_name, :erlang.phash2(args)}
      end

      defp create_rate_limited_error(retry_after) do
        ElixirScope.Foundation.Types.Error.new(
          code: 4029,
          error_type: :rate_limited,
          message: "Rate limit exceeded",
          severity: :medium,
          context: %{retry_after_ms: retry_after},
          category: :external,
          subcategory: :rate_limit
        )
      end
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.RateLimitMiddleware do
  @moduledoc """
  Middleware for applying rate limiting to requests.
  """

  alias ElixirScope.Foundation.Infrastructure.RateLimiter

  @doc """
  Apply rate limiting to a request.
  """
  @spec call(map(), keyword()) :: map()
  def call(request, opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    rate_key = extract_rate_key(request, opts)
    rate_config = get_rate_config(request, opts)

    case RateLimiter.check_rate_limit(namespace, rate_key, rate_config) do
      :ok ->
        request

      {:error, :rate_limited, retry_after} ->
        raise RateLimitExceededError, retry_after: retry_after
    end
  end

  @spec extract_rate_key(map(), keyword()) :: term()
  defp extract_rate_key(request, opts) do
    case Keyword.get(opts, :key_strategy) do
      :ip -> get_client_ip(request)
      :user -> get_user_id(request)
      :api_key -> get_api_key(request)
      :path -> get_request_path(request)
      custom_fun when is_function(custom_fun) -> custom_fun.(request)
      _ -> :default
    end
  end

  @spec get_rate_config(map(), keyword()) :: map()
  defp get_rate_config(_request, opts) do
    Keyword.get(opts, :rate_config, %{
      algorithm: :token_bucket,
      limit: 100,
      window_ms: 60_000,
      burst_limit: 120
    })
  end

  # Helper functions for extracting rate limit keys
  defp get_client_ip(request), do: Map.get(request, :remote_ip, "unknown")
  defp get_user_id(request), do: Map.get(request, :user_id, "anonymous")
  defp get_api_key(request), do: Map.get(request, :api_key, "no_key")
  defp get_request_path(request), do: Map.get(request, :path, "/")
end

defmodule RateLimitExceededError do
  @moduledoc """
  Exception raised when rate limit is exceeded.
  """
  defexception [:retry_after]

  def message(%{retry_after: retry_after}) do
    "Rate limit exceeded. Retry after #{retry_after}ms"
  end
end
