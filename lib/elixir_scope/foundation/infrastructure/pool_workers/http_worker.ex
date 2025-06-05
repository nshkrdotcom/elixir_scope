defmodule ElixirScope.Foundation.Infrastructure.PoolWorkers.HttpWorker do
  @moduledoc """
  Sample HTTP connection pool worker for demonstrating connection pooling patterns.

  This worker maintains persistent HTTP connections and provides a reusable
  template for implementing custom pool workers for different resource types.

  ## Usage

      # Start pool with HTTP workers
      ConnectionManager.start_pool(:http_pool, [
        size: 10,
        max_overflow: 5,
        worker_module: ElixirScope.Foundation.Infrastructure.PoolWorkers.HttpWorker,
        worker_args: [base_url: "https://api.example.com", timeout: 30_000]
      ])

      # Use pooled connection
      ConnectionManager.with_connection(:http_pool, fn worker ->
        HttpWorker.get(worker, "/users/123")
      end)

  ## Worker Configuration

  - `:base_url` - Base URL for HTTP requests
  - `:timeout` - Request timeout in milliseconds
  - `:headers` - Default headers for all requests
  - `:max_redirects` - Maximum number of redirects to follow
  """

  use GenServer
  require Logger

  @type worker_config :: [
          base_url: String.t(),
          timeout: timeout(),
          headers: [{String.t(), String.t()}],
          max_redirects: non_neg_integer()
        ]

  @default_config [
    timeout: 30_000,
    headers: [{"User-Agent", "ElixirScope/1.0"}],
    max_redirects: 5
  ]

  ## Public API

  @doc """
  Starts an HTTP worker with the given configuration.

  This function is called by Poolboy to create worker instances.
  """
  @spec start_link(worker_config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc """
  Performs a GET request using the pooled worker.

  ## Parameters
  - `worker` - Worker PID from the pool
  - `path` - Request path (relative to base_url)
  - `options` - Request options (headers, params, etc.)

  ## Returns
  - `{:ok, response}` - Request successful
  - `{:error, reason}` - Request failed
  """
  @spec get(pid(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(worker, path, options \\ []) do
    GenServer.call(worker, {:get, path, options})
  end

  @doc """
  Performs a POST request using the pooled worker.

  ## Parameters
  - `worker` - Worker PID from the pool
  - `path` - Request path (relative to base_url)
  - `body` - Request body (will be JSON encoded)
  - `options` - Request options (headers, etc.)

  ## Returns
  - `{:ok, response}` - Request successful
  - `{:error, reason}` - Request failed
  """
  @spec post(pid(), String.t(), term(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(worker, path, body, options \\ []) do
    GenServer.call(worker, {:post, path, body, options})
  end

  @doc """
  Gets the current status and configuration of the worker.

  ## Parameters
  - `worker` - Worker PID from the pool

  ## Returns
  - `{:ok, status}` - Worker status information
  """
  @spec get_status(pid()) :: {:ok, map()}
  def get_status(worker) do
    GenServer.call(worker, :get_status)
  end

  ## GenServer Implementation

  @typep state :: %{
           base_url: String.t(),
           timeout: timeout(),
           headers: [{String.t(), String.t()}],
           max_redirects: non_neg_integer(),
           stats: %{
             requests_made: non_neg_integer(),
             last_request_at: DateTime.t() | nil,
             errors: non_neg_integer()
           }
         }

  @impl GenServer
  def init(config) do
    merged_config = Keyword.merge(@default_config, config)

    state = %{
      base_url: Keyword.fetch!(merged_config, :base_url),
      timeout: Keyword.get(merged_config, :timeout),
      headers: Keyword.get(merged_config, :headers),
      max_redirects: Keyword.get(merged_config, :max_redirects),
      stats: %{
        requests_made: 0,
        last_request_at: nil,
        errors: 0
      }
    }

    Logger.debug("HTTP worker started for #{state.base_url}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get, path, options}, _from, state) do
    case do_http_request(:get, path, nil, options, state) do
      {:ok, response, new_state} ->
        {:reply, {:ok, response}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:post, path, body, options}, _from, state) do
    case do_http_request(:post, path, body, options, state) do
      {:ok, response, new_state} ->
        {:reply, {:ok, response}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      base_url: state.base_url,
      timeout: state.timeout,
      stats: state.stats,
      uptime: get_uptime()
    }

    {:reply, {:ok, status}, state}
  end

  ## Private Functions

  @spec do_http_request(atom(), String.t(), term(), keyword(), state()) ::
          {:ok, map(), state()} | {:error, term(), state()}
  defp do_http_request(method, path, body, options, state) do
    url = build_url(state.base_url, path)
    headers = merge_headers(state.headers, Keyword.get(options, :headers, []))

    request_options = [
      timeout: state.timeout,
      max_redirects: state.max_redirects
    ]

    start_time = System.monotonic_time()

    try do
      case perform_request(method, url, body, headers, request_options) do
        {:ok, response} ->
          duration = System.monotonic_time() - start_time
          new_state = update_stats(state, :success, duration)

          Logger.debug("HTTP #{method} #{url} completed in #{duration}μs")
          {:ok, response, new_state}

        {:error, reason} ->
          duration = System.monotonic_time() - start_time
          new_state = update_stats(state, :error, duration)

          Logger.warning("HTTP #{method} #{url} failed: #{inspect(reason)}")
          {:error, reason, new_state}
      end
    rescue
      error ->
        duration = System.monotonic_time() - start_time
        new_state = update_stats(state, :error, duration)

        Logger.error("HTTP #{method} #{url} exception: #{inspect(error)}")
        {:error, {:exception, error}, new_state}
    end
  end

  @spec build_url(String.t(), String.t()) :: String.t()
  defp build_url(base_url, path) do
    base_url = String.trim_trailing(base_url, "/")
    path = String.trim_leading(path, "/")
    "#{base_url}/#{path}"
  end

  @spec merge_headers([{String.t(), String.t()}], [{String.t(), String.t()}]) ::
          [{String.t(), String.t()}]
  defp merge_headers(default_headers, request_headers) do
    # Request headers override default headers
    default_map = Enum.into(default_headers, %{})
    request_map = Enum.into(request_headers, %{})

    Map.merge(default_map, request_map)
    |> Enum.to_list()
  end

  @spec perform_request(atom(), String.t(), term(), [{String.t(), String.t()}], keyword()) ::
          {:ok, map()} | {:error, term()}
  defp perform_request(method, url, body, headers, _options) do
    # This is a mock implementation - in real usage, you'd use HTTPoison, Finch, etc.
    # For demonstration purposes, we'll simulate HTTP requests

    # Simulate network latency
    Process.sleep(Enum.random(10..100))

    case Enum.random(1..10) do
      n when n <= 8 ->
        # 80% success rate
        response = %{
          status_code: 200,
          headers: [{"content-type", "application/json"}],
          body: %{
            method: method,
            url: url,
            timestamp: DateTime.utc_now(),
            headers: headers,
            body: body
          }
        }

        {:ok, response}

      9 ->
        # 10% client errors
        {:error, {:http_error, 404, "Not Found"}}

      10 ->
        # 10% network errors
        {:error, :timeout}
    end
  end

  @spec update_stats(state(), :success | :error, integer()) :: state()
  defp update_stats(state, result, _duration) do
    new_stats = %{
      state.stats
      | requests_made: state.stats.requests_made + 1,
        last_request_at: DateTime.utc_now(),
        errors:
          case result do
            :success -> state.stats.errors
            :error -> state.stats.errors + 1
          end
    }

    %{state | stats: new_stats}
  end

  @spec get_uptime() :: integer()
  defp get_uptime do
    # This is a simplified uptime calculation
    # In practice, you might store the start time in the state
    System.monotonic_time()
  end
end
