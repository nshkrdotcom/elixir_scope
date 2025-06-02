defmodule ElixirScope.Foundation.ProcessRegistry do
  @moduledoc """
  Centralized process registry for ElixirScope Foundation layer.

  Provides namespace isolation using Registry to enable concurrent testing
  and prevent naming conflicts between production and test environments.

  ## Supported Namespaces

  - `:production` - For normal operation
  - `{:test, reference()}` - For test isolation with unique references

  ## Examples

      # Register a service in production
      :ok = ProcessRegistry.register(:production, :config_server, self())

      # Register in test namespace
      test_ref = make_ref()
      :ok = ProcessRegistry.register({:test, test_ref}, :config_server, self())

      # Lookup services
      {:ok, pid} = ProcessRegistry.lookup(:production, :config_server)
  """

  @type namespace :: :production | {:test, reference()}
  @type service_name :: 
    :config_server | 
    :event_store | 
    :telemetry_service | 
    :test_supervisor

  @type registry_key :: {namespace(), service_name()}

  @doc """
  Child specification for supervision tree integration.
  """
  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__,
      partitions: System.schedulers_online()
    )
  end

  @doc """
  Register a service in the given namespace.

  ## Parameters
  - `namespace`: The namespace for service isolation
  - `service`: The service name to register
  - `pid`: The process PID to register

  ## Returns
  - `:ok` if registration succeeds
  - `{:error, {:already_registered, pid}}` if name already taken

  ## Examples

      iex> ProcessRegistry.register(:production, :config_server, self())
      :ok

      iex> ProcessRegistry.register(:production, :config_server, self())
      {:error, {:already_registered, #PID<0.123.0>}}
  """
  @spec register(namespace(), service_name(), pid()) :: :ok | {:error, {:already_registered, pid()}}
  def register(namespace, service, pid) when is_pid(pid) do
    case Registry.register(__MODULE__, {namespace, service}, nil) do
      {:ok, _owner} -> 
        :ok
      {:error, {:already_registered, existing_pid}} -> 
        {:error, {:already_registered, existing_pid}}
    end
  end

  @doc """
  Look up a service in the given namespace.

  ## Parameters
  - `namespace`: The namespace to search in
  - `service`: The service name to lookup

  ## Returns
  - `{:ok, pid}` if service found
  - `:error` if service not found

  ## Examples

      iex> ProcessRegistry.lookup(:production, :config_server)
      {:ok, #PID<0.123.0>}

      iex> ProcessRegistry.lookup(:production, :nonexistent)
      :error
  """
  @spec lookup(namespace(), service_name()) :: {:ok, pid()} | :error
  def lookup(namespace, service) do
    case Registry.lookup(__MODULE__, {namespace, service}) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Unregister a service from the given namespace.

  Note: This is typically not needed as Registry automatically
  unregisters when the process dies.

  ## Parameters
  - `namespace`: The namespace containing the service
  - `service`: The service name to unregister

  ## Returns
  - `:ok` regardless of whether service was registered

  ## Examples

      iex> ProcessRegistry.unregister(:production, :config_server)
      :ok
  """
  @spec unregister(namespace(), service_name()) :: :ok
  def unregister(namespace, service) do
    Registry.unregister(__MODULE__, {namespace, service})
  end

  @doc """
  List all services registered in a namespace.

  ## Parameters
  - `namespace`: The namespace to list services for

  ## Returns
  - List of service names registered in the namespace

  ## Examples

      iex> ProcessRegistry.list_services(:production)
      [:config_server, :event_store, :telemetry_service]

      iex> ProcessRegistry.list_services({:test, test_ref})
      []
  """
  @spec list_services(namespace()) :: [service_name()]
  def list_services(namespace) do
    Registry.select(__MODULE__, [
      {{{namespace, :"$1"}, :"$2", :"$3"}, [], [:"$1"]}
    ])
  end

  @doc """
  Get all registered services with their PIDs for a namespace.

  ## Parameters
  - `namespace`: The namespace to get services for

  ## Returns
  - Map of service_name => pid

  ## Examples

      iex> ProcessRegistry.get_all_services(:production)
      %{
        config_server: #PID<0.123.0>,
        event_store: #PID<0.124.0>
      }
  """
  @spec get_all_services(namespace()) :: %{service_name() => pid()}
  def get_all_services(namespace) do
    Registry.select(__MODULE__, [
      {{{namespace, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}
    ])
    |> Enum.into(%{})
  end

  @doc """
  Check if a service is registered in a namespace.

  ## Parameters
  - `namespace`: The namespace to check
  - `service`: The service name to check

  ## Returns
  - `true` if service is registered
  - `false` if service is not registered

  ## Examples

      iex> ProcessRegistry.registered?(namespace, :config_server)
      true
  """
  @spec registered?(namespace(), service_name()) :: boolean()
  def registered?(namespace, service) do
    case lookup(namespace, service) do
      {:ok, _pid} -> true
      :error -> false
    end
  end

  @doc """
  Count the number of services in a namespace.

  ## Parameters
  - `namespace`: The namespace to count services in

  ## Returns
  - Non-negative integer count of services

  ## Examples

      iex> ProcessRegistry.count_services(:production)
      3
  """
  @spec count_services(namespace()) :: non_neg_integer()
  def count_services(namespace) do
    Registry.select(__MODULE__, [
      {{{namespace, :"$1"}, :"$2", :"$3"}, [], [true]}
    ])
    |> length()
  end

  @doc """
  Create a via tuple for GenServer registration.

  This is used in GenServer.start_link/3 for automatic registration.

  ## Parameters
  - `namespace`: The namespace for the service
  - `service`: The service name

  ## Returns
  - Via tuple for GenServer registration

  ## Examples

      iex> via = ProcessRegistry.via_tuple(:production, :config_server)
      iex> GenServer.start_link(MyServer, [], name: via)
  """
  @spec via_tuple(namespace(), service_name()) :: {:via, Registry, {atom(), registry_key()}}
  def via_tuple(namespace, service) do
    {:via, Registry, {__MODULE__, {namespace, service}}}
  end

  @doc """
  Cleanup all services in a test namespace.

  This is useful for test cleanup - terminates all processes
  registered in the given test namespace.

  ## Parameters
  - `test_ref`: The test reference used in namespace

  ## Returns
  - `:ok` after cleanup is complete

  ## Examples

      iex> test_ref = make_ref()
      iex> # ... register services in {:test, test_ref} ...
      iex> ProcessRegistry.cleanup_test_namespace(test_ref)
      :ok
  """
  @spec cleanup_test_namespace(reference()) :: :ok
  def cleanup_test_namespace(test_ref) do
    namespace = {:test, test_ref}
    
    # Get all PIDs in this namespace
    pids = Registry.select(__MODULE__, [
      {{{namespace, :"$1"}, :"$2", :"$3"}, [], [:"$2"]}
    ])
    
    # Terminate each process gracefully
    Enum.each(pids, fn pid ->
      if Process.alive?(pid) do
        # Try graceful shutdown first
        Process.exit(pid, :shutdown)
        
        # Wait a brief moment for graceful shutdown
        receive do
        after 100 -> :ok
        end
        
        # Force kill if still alive
        if Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end
    end)
    
    :ok
  end

  @doc """
  Get registry statistics for monitoring.

  ## Returns
  - Map with registry statistics

  ## Examples

      iex> ProcessRegistry.stats()
      %{
        total_services: 15,
        production_services: 3,
        test_namespaces: 4,
        partitions: 8
      }
  """
  @spec stats() :: %{
          total_services: non_neg_integer(),
          production_services: non_neg_integer(),
          test_namespaces: non_neg_integer(),
          partitions: pos_integer()
        }
  def stats() do
    all_entries = Registry.select(__MODULE__, [
      {{{:"$1", :"$2"}, :"$3", :"$4"}, [], [:"$1"]}
    ])
    
    {production_count, test_namespaces} = 
      Enum.reduce(all_entries, {0, MapSet.new()}, fn
        :production, {prod_count, test_set} ->
          {prod_count + 1, test_set}
        {:test, ref}, {prod_count, test_set} ->
          {prod_count, MapSet.put(test_set, ref)}
      end)

    %{
      total_services: length(all_entries),
      production_services: production_count,
      test_namespaces: MapSet.size(test_namespaces),
      partitions: System.schedulers_online()
    }
  end
end 