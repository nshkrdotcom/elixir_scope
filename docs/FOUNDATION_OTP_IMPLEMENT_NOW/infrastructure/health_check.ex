defmodule ElixirScope.Foundation.Infrastructure.HealthCheck do
  @moduledoc """
  Enhanced health check framework for Foundation services.

  Provides deep health validation with dependency checking and recovery.
  Establishes comprehensive monitoring patterns for higher layers.

  ## Health Check Types
  - Self diagnostic: Service internal health
  - Dependency check: Required services availability
  - Deep health: Comprehensive validation including data integrity
  """

  @type t :: health_result()

  @type health_status :: :healthy | :degraded | :unhealthy
  @type health_result :: %{
          status: health_status(),
          checks: [check_result()],
          overall_score: float(),
          timestamp: DateTime.t(),
          duration_ms: non_neg_integer()
        }

  @type check_result :: %{
          name: atom(),
          status: health_status(),
          message: String.t(),
          metadata: map(),
          duration_ms: non_neg_integer()
        }

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @doc """
  Perform comprehensive health check for a service.
  """
  @spec deep_health_check(ServiceRegistry.namespace(), atom()) :: health_result()
  def deep_health_check(namespace, service) do
    start_time = System.monotonic_time(:millisecond)

    checks =
      [
        self_diagnostic(namespace, service),
        dependency_health_check(namespace, service),
        performance_check(namespace, service)
      ]
      |> List.flatten()
      |> Enum.filter(&(&1 != nil))

    duration = System.monotonic_time(:millisecond) - start_time

    %{
      status: calculate_overall_status(checks),
      checks: checks,
      overall_score: calculate_health_score(checks),
      timestamp: DateTime.utc_now(),
      duration_ms: duration
    }
  end

  @doc """
  Quick health check for a service.
  """
  @spec quick_health_check(ServiceRegistry.namespace(), atom()) :: health_status()
  def quick_health_check(namespace, service) do
    case ServiceRegistry.health_check(namespace, service) do
      {:ok, _pid} -> :healthy
      {:error, _} -> :unhealthy
    end
  end

  ## Private Functions

  @spec self_diagnostic(ServiceRegistry.namespace(), atom()) :: check_result()
  defp self_diagnostic(namespace, service) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case ServiceRegistry.lookup(namespace, service) do
        {:ok, pid} ->
          if Process.alive?(pid) do
            case service_specific_diagnostic(namespace, service, pid) do
              {:ok, metadata} ->
                %{status: :healthy, message: "Service operational", metadata: metadata}

              {:degraded, metadata} ->
                %{status: :degraded, message: "Service degraded", metadata: metadata}

              {:error, reason} ->
                %{
                  status: :unhealthy,
                  message: "Service unhealthy: #{inspect(reason)}",
                  metadata: %{}
                }
            end
          else
            %{status: :unhealthy, message: "Process not alive", metadata: %{}}
          end

        {:error, _} ->
          %{status: :unhealthy, message: "Service not found", metadata: %{}}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    Map.merge(result, %{
      name: :"#{service}_self_diagnostic",
      duration_ms: duration
    })
  end

  @spec dependency_health_check(ServiceRegistry.namespace(), atom()) :: [check_result()]
  defp dependency_health_check(namespace, service) do
    dependencies = get_service_dependencies(service)

    Enum.map(dependencies, fn dep_service ->
      start_time = System.monotonic_time(:millisecond)

      result =
        case ServiceRegistry.health_check(namespace, dep_service) do
          {:ok, _pid} ->
            %{status: :healthy, message: "Dependency available", metadata: %{service: dep_service}}

          {:error, :service_not_found} ->
            %{
              status: :unhealthy,
              message: "Dependency not found",
              metadata: %{service: dep_service}
            }

          {:error, :process_dead} ->
            %{
              status: :unhealthy,
              message: "Dependency process dead",
              metadata: %{service: dep_service}
            }

          {:error, reason} ->
            %{
              status: :degraded,
              message: "Dependency issue: #{inspect(reason)}",
              metadata: %{service: dep_service}
            }
        end

      duration = System.monotonic_time(:millisecond) - start_time

      Map.merge(result, %{
        name: :"#{service}_dependency_#{dep_service}",
        duration_ms: duration
      })
    end)
  end

  @spec performance_check(ServiceRegistry.namespace(), atom()) :: check_result() | nil
  defp performance_check(namespace, service) do
    start_time = System.monotonic_time(:millisecond)

    case ServiceRegistry.lookup(namespace, service) do
      {:ok, pid} ->
        case Process.info(pid, [:message_queue_len, :memory, :reductions]) do
          info when is_list(info) ->
            queue_len = Keyword.get(info, :message_queue_len, 0)
            memory = Keyword.get(info, :memory, 0)
            reductions = Keyword.get(info, :reductions, 0)

            {status, message} =
              cond do
                queue_len > 1000 -> {:degraded, "High message queue length"}
                # 50MB
                memory > 50_000_000 -> {:degraded, "High memory usage"}
                true -> {:healthy, "Performance within normal range"}
              end

            duration = System.monotonic_time(:millisecond) - start_time

            %{
              name: :"#{service}_performance",
              status: status,
              message: message,
              metadata: %{
                queue_length: queue_len,
                memory_bytes: memory,
                reductions: reductions
              },
              duration_ms: duration
            }

          nil ->
            duration = System.monotonic_time(:millisecond) - start_time

            %{
              name: :"#{service}_performance",
              status: :unhealthy,
              message: "Could not get process info",
              metadata: %{},
              duration_ms: duration
            }
        end

      {:error, _} ->
        nil
    end
  end

  @spec service_specific_diagnostic(ServiceRegistry.namespace(), atom(), pid()) ::
          {:ok, map()} | {:degraded, map()} | {:error, term()}
  defp service_specific_diagnostic(namespace, :config_server, pid) do
    try do
      # Test basic config retrieval
      case GenServer.call(pid, {:get_config_path, [:ai, :provider]}, 1000) do
        {:ok, _} -> {:ok, %{config_accessible: true}}
        # Default value
        :mock -> {:ok, %{config_accessible: true}}
        nil -> {:degraded, %{config_accessible: false, reason: "path_not_found"}}
        {:error, reason} -> {:error, reason}
      end
    catch
      :exit, {:timeout, _} -> {:degraded, %{config_accessible: false, reason: "timeout"}}
      :exit, reason -> {:error, reason}
    end
  end

  defp service_specific_diagnostic(namespace, :event_store, pid) do
    try do
      # Test basic event store functionality
      case GenServer.call(pid, :get_stats, 1000) do
        {:ok, stats} ->
          event_count = Map.get(stats, :current_event_count, 0)

          if event_count >= 0 do
            {:ok, %{event_store_accessible: true, event_count: event_count}}
          else
            {:degraded, %{event_store_accessible: false, reason: "invalid_stats"}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    catch
      :exit, {:timeout, _} -> {:degraded, %{event_store_accessible: false, reason: "timeout"}}
      :exit, reason -> {:error, reason}
    end
  end

  defp service_specific_diagnostic(namespace, :telemetry_service, pid) do
    try do
      # Test basic telemetry functionality
      case GenServer.call(pid, :get_status, 1000) do
        {:ok, status} ->
          if Map.get(status, :status) == :running do
            {:ok, %{telemetry_accessible: true, status: status}}
          else
            {:degraded, %{telemetry_accessible: false, status: status}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    catch
      :exit, {:timeout, _} -> {:degraded, %{telemetry_accessible: false, reason: "timeout"}}
      :exit, reason -> {:error, reason}
    end
  end

  defp service_specific_diagnostic(namespace, _service, _pid) do
    {:ok, %{basic_health: true}}
  end

  @spec get_service_dependencies(atom()) :: [atom()]
  defp get_service_dependencies(:config_server), do: []
  defp get_service_dependencies(:event_store), do: [:config_server]
  defp get_service_dependencies(:telemetry_service), do: [:config_server]
  defp get_service_dependencies(_), do: []

  @spec calculate_overall_status([check_result()]) :: health_status()
  defp calculate_overall_status(checks) do
    statuses = Enum.map(checks, & &1.status)

    cond do
      Enum.any?(statuses, &(&1 == :unhealthy)) -> :unhealthy
      Enum.any?(statuses, &(&1 == :degraded)) -> :degraded
      true -> :healthy
    end
  end

  @spec calculate_health_score([check_result()]) :: float()
  defp calculate_health_score([]), do: 0.0

  defp calculate_health_score(checks) do
    scores =
      Enum.map(checks, fn check ->
        case check.status do
          :healthy -> 1.0
          :degraded -> 0.5
          :unhealthy -> 0.0
        end
      end)

    Enum.sum(scores) / length(scores)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.HealthAggregator do
  @moduledoc """
  Aggregates health information across all services in a namespace.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}
  alias ElixirScope.Foundation.Infrastructure.HealthCheck

  @type system_health :: %{
          status: HealthCheck.health_status(),
          services: [{atom(), HealthCheck.health_result()}],
          overall_score: float(),
          healthy_services: non_neg_integer(),
          total_services: non_neg_integer(),
          timestamp: DateTime.t()
        }

  ## Public API

  @doc """
  Start the health aggregator for a namespace.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ServiceRegistry.via_tuple(namespace, :health_aggregator)
    GenServer.start_link(__MODULE__, [namespace: namespace], name: name)
  end

  @doc """
  Get comprehensive system health for a namespace.
  """
  @spec system_health(ServiceRegistry.namespace()) :: {:ok, system_health()} | {:error, term()}
  def system_health(namespace) do
    case ServiceRegistry.lookup(namespace, :health_aggregator) do
      {:ok, pid} ->
        GenServer.call(pid, :get_system_health, 10_000)

      {:error, _} ->
        # Fallback: perform direct health check
        perform_direct_health_check(namespace)
    end
  end

  @doc """
  Get quick health status for all services.
  """
  @spec quick_system_health(ServiceRegistry.namespace()) :: {:ok, map()} | {:error, term()}
  def quick_system_health(namespace) do
    services = ServiceRegistry.list_services(namespace)

    health_results =
      Enum.map(services, fn service ->
        status = HealthCheck.quick_health_check(namespace, service)
        {service, status}
      end)

    healthy_count = Enum.count(health_results, fn {_, status} -> status == :healthy end)
    total_count = length(health_results)

    overall_status =
      cond do
        healthy_count == 0 -> :unhealthy
        healthy_count < total_count -> :degraded
        true -> :healthy
      end

    {:ok,
     %{
       status: overall_status,
       services: health_results,
       healthy_services: healthy_count,
       total_services: total_count,
       timestamp: DateTime.utc_now()
     }}
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)

    state = %{
      namespace: namespace,
      last_health_check: nil,
      cached_results: %{}
    }

    Logger.info("Health aggregator started for namespace #{inspect(namespace)}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_system_health, _from, state) do
    services = ServiceRegistry.list_services(state.namespace)

    health_results =
      Enum.map(services, fn service ->
        try do
          result = HealthCheck.deep_health_check(state.namespace, service)
          {service, result}
        rescue
          error ->
            Logger.warning("Health check failed for #{service}: #{inspect(error)}")

            {service,
             %{
               status: :unhealthy,
               checks: [],
               overall_score: 0.0,
               timestamp: DateTime.utc_now(),
               duration_ms: 0,
               error: inspect(error)
             }}
        catch
          :exit, {:timeout, _} ->
            {service,
             %{
               status: :unhealthy,
               checks: [],
               overall_score: 0.0,
               timestamp: DateTime.utc_now(),
               duration_ms: 10_000,
               error: "health_check_timeout"
             }}
        end
      end)

    system_health = calculate_system_health(health_results)

    new_state = %{
      state
      | last_health_check: DateTime.utc_now(),
        cached_results: Map.new(health_results)
    }

    {:reply, {:ok, system_health}, new_state}
  end

  ## Private Functions

  @spec perform_direct_health_check(ServiceRegistry.namespace()) :: {:ok, system_health()}
  defp perform_direct_health_check(namespace) do
    services = ServiceRegistry.list_services(namespace)

    health_results =
      Enum.map(services, fn service ->
        result = HealthCheck.deep_health_check(namespace, service)
        {service, result}
      end)

    system_health = calculate_system_health(health_results)
    {:ok, system_health}
  end

  @spec calculate_system_health([{atom(), HealthCheck.health_result()}]) :: system_health()
  defp calculate_system_health(service_results) do
    total_services = length(service_results)

    healthy_services =
      Enum.count(service_results, fn {_, result} ->
        result.status == :healthy
      end)

    overall_score =
      if total_services > 0 do
        scores = Enum.map(service_results, fn {_, result} -> result.overall_score end)
        Enum.sum(scores) / total_services
      else
        0.0
      end

    overall_status = determine_system_status(overall_score, healthy_services, total_services)

    %{
      status: overall_status,
      services: service_results,
      overall_score: overall_score,
      healthy_services: healthy_services,
      total_services: total_services,
      timestamp: DateTime.utc_now()
    }
  end

  @spec determine_system_status(float(), non_neg_integer(), non_neg_integer()) ::
          HealthCheck.health_status()
  defp determine_system_status(overall_score, healthy_services, total_services) do
    cond do
      overall_score >= 0.8 and healthy_services == total_services -> :healthy
      overall_score >= 0.5 and healthy_services > 0 -> :degraded
      true -> :unhealthy
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.HealthEndpoint do
  @moduledoc """
  HTTP-compatible health check endpoint integration.
  """

  alias ElixirScope.Foundation.Infrastructure.HealthAggregator

  @doc """
  Get health check in JSON format for HTTP endpoints.
  """
  @spec health_check_json(ServiceRegistry.namespace()) :: map()
  def health_check_json(namespace \\ :production) do
    case HealthAggregator.system_health(namespace) do
      {:ok, health} ->
        %{
          status: health.status,
          timestamp: DateTime.to_iso8601(health.timestamp),
          services: format_service_health(health.services),
          overall_score: health.overall_score,
          healthy_services: health.healthy_services,
          total_services: health.total_services
        }

      {:error, reason} ->
        %{
          status: :error,
          message: "Health check failed: #{inspect(reason)}",
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }
    end
  end

  @doc """
  Get quick health check for load balancer endpoints.
  """
  @spec quick_health_json(ServiceRegistry.namespace()) :: map()
  def quick_health_json(namespace \\ :production) do
    case HealthAggregator.quick_system_health(namespace) do
      {:ok, health} ->
        %{
          status: health.status,
          healthy: health.healthy_services,
          total: health.total_services,
          timestamp: DateTime.to_iso8601(health.timestamp)
        }

      {:error, reason} ->
        %{
          status: :error,
          message: inspect(reason),
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }
    end
  end

  ## Private Functions

  @spec format_service_health([{atom(), map()}]) :: map()
  defp format_service_health(services) do
    Enum.into(services, %{}, fn {service_name, health_result} ->
      formatted_result = %{
        status: health_result.status,
        score: health_result.overall_score,
        duration_ms: health_result.duration_ms,
        checks: Enum.map(health_result.checks, &format_check_result/1)
      }

      {service_name, formatted_result}
    end)
  end

  @spec format_check_result(map()) :: map()
  defp format_check_result(check) do
    %{
      name: check.name,
      status: check.status,
      message: check.message,
      duration_ms: check.duration_ms,
      metadata: check.metadata
    }
  end
end
