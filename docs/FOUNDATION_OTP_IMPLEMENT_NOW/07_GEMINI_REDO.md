Right, let's continue building out the `MyApp.Registry` API module and then discuss how services use it.

```elixir
# lib/my_app/registry.ex (or lib/my_app/services/registry.ex)
defmodule MyApp.Registry do
  @registry_name MyApp.CoreRegistry # As defined in application.ex

  @doc """
  Registers the calling process under the given key.
  The `value` is optional metadata to store alongside the process.
  Often, the PID itself is enough, so `value` can be `nil` or the PID.
  """
  def register(key, value \\ self()) do
    # Registry.register/3 registers the calling process (self())
    # The third argument is the value associated with the key for this process.
    # Storing `self()` as the value is common if you don't need other metadata.
    Registry.register(@registry_name, key, value)
  end

  @doc """
  Looks up the PID(s) and associated value(s) for a key.
  For a `:unique` registry, this will return `[{pid, value}]` or `[]`.
  For a `:duplicate` registry, it can return multiple `[{pid1, val1}, {pid2, val2}]`.
  """
  def lookup(key) do
    Registry.lookup(@registry_name, key)
  end

  @doc """
  Convenience function to get the first PID for a key.
  Returns `{:ok, pid}` or `{:error, :not_found}`.
  Useful when you expect a single process for a unique key.
  """
  def whereis(key) do
    case Registry.lookup(@registry_name, key) do
      [{pid, _value} | _] -> {:ok, pid} # Takes the first one, assumes unique or first is fine
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Deregisters a process by key.
  Note: `Registry` automatically unregisters processes when they exit.
  This function is for explicit deregistration while the process is still alive.
  It removes all processes registered under `key`.
  """
  def unregister(key) do
    Registry.unregister(@registry_name, key)
  end

  @doc """
  Lists all registered entries as `{key, pid, value}` tuples.
  This can be expensive for very large registries; use with caution.
  The match spec `{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}`
  returns tuples of {key, pid, value}.
  """
  def all_registered do
    Registry.select(@registry_name, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
  end

  @doc """
  Counts how many processes are registered under a given key.
  """
  def count(key) do
    Registry.count_match(@registry_name, key)
  end

  @doc """
  Returns a list of all unique keys currently in the registry.
  """
  def keys do
    # Match spec to extract just the key (first element of the ETS key tuple)
    Registry.select(@registry_name, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.uniq() # Ensure keys are unique if the match somehow returns duplicates (shouldn't for keys)
  end

  @doc """
  Creates a "via" tuple for registering or looking up GenServers by name.
  This allows `GenServer.start_link({:via, MyApp.Registry, key}, ...)`
  and `GenServer.call({:via, MyApp.Registry, key}, :message)`.
  """
  def via_tuple(key) do
    {:via, Registry, {@registry_name, key}}
  end
end
```

**Notes on the API Module:**
*   **`register/2`**: I've set the default `value` to `self()`. This is a common pattern. If you need more metadata, the calling process can supply it.
*   **`whereis/1`**: This is a common helper. `Registry.lookup/2` always returns a list.
*   **`unregister/1`**: Useful for explicit cleanup, though automatic cleanup on process exit is a key feature of `Registry`.
*   **`all_registered/0` and `keys/0`**: These can be useful for debugging or admin interfaces, but be mindful of performance on very large registries as they iterate over the ETS table.
*   **`via_tuple/1`**: This is **critical** for idiomatic GenServer registration and lookup.

---

### 3. Services (GenServers) Using the Registry

The most idiomatic way for GenServers to be registered and looked up is using the `:via` mechanism.

**a. Starting and Registering a GenServer:**

```elixir
# lib/my_app/services/user_service.ex
defmodule MyApp.Services.UserService do
  use GenServer

  alias MyApp.Registry # Our API module

  # Client API
  def start_link(user_id) do
    # The key under which this service instance will be registered
    service_key = {:user_service, user_id}

    # Use the :via tuple for naming. This handles registration automatically.
    GenServer.start_link(__MODULE__, %{user_id: user_id}, name: Registry.via_tuple(service_key))
  end

  def get_user_details(user_id) do
    service_key = {:user_service, user_id}
    # Use the :via tuple for lookup and call
    GenServer.call(Registry.via_tuple(service_key), :get_details)
  end

  # Server Callbacks
  @impl true
  def init(state) do
    # No explicit registration needed here if using :via in start_link.
    # `Registry` handles it.
    # If you weren't using :via, you might do:
    # service_key = {:user_service, state.user_id}
    # case Registry.register(service_key, %{started_at: DateTime.utc_now()}) do
    #   {:ok, _pid} -> {:ok, state}
    #   {:error, {:already_registered, _pid}} -> {:stop, :already_registered} # Or handle differently
    # end
    IO.puts("User Service for #{state.user_id} started.")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_details, _from, state) do
    # Simulate fetching user details
    details = %{id: state.user_id, name: "User #{state.user_id}", email: "user#{state.user_id}@example.com"}
    {:reply, {:ok, details}, state}
  end

  # ... other callbacks
end
```

**Key points for GenServers:**
*   **`Registry.via_tuple(key)`**: When passed as the `:name` option to `GenServer.start_link/3`, Elixir's `Registry` machinery will automatically:
    1.  Call `Registry.register(MyApp.CoreRegistry, key, _value)` when the GenServer starts.
    2.  Monitor the GenServer.
    3.  Call `Registry.unregister(MyApp.CoreRegistry, key)` when the GenServer terminates.
*   This makes registration and deregistration transparent and robust.
*   Client functions also use `Registry.via_tuple(key)` to send messages to the named GenServer.

**b. Supervising these Services:**

You'll likely use a `DynamicSupervisor` if you're starting these services on demand (e.g., one `UserService` per active user).

```elixir
# lib/my_app/services/supervisor.ex
defmodule MyApp.Services.Supervisor do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Public API to start services
  def start_user_service(user_id) do
    spec = {MyApp.Services.UserService, user_id} # Arguments to UserService.start_link/1
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  # You might also have a function to ensure a service is running
  def ensure_user_service_started(user_id) do
    service_key = {:user_service, user_id}
    case MyApp.Registry.whereis(service_key) do
      {:ok, _pid} -> # Already running
        {:ok, _pid}
      {:error, :not_found} ->
        start_user_service(user_id)
    end
  end
end
```

And add this supervisor to your main application's supervision tree:
```elixir
# lib/my_app/application.ex
# ...
  children = [
    {Registry, keys: :unique, name: MyApp.CoreRegistry},
    MyApp.Services.Supervisor # Add the dynamic supervisor
  ]
# ...
```

---

### 4. Considerations and Best Practices

*   **Key Design**:
    *   Use meaningful, structured keys. Tuples are excellent for this (e.g., `{:service_name, id}`, `{:cache, :users_by_id}`).
    *   Decide if keys should be atoms or strings. Atoms are generally preferred for static keys, but be mindful of the atom table limit if keys are highly dynamic and user-generated (strings might be better then, or a combination like `{:user_generated_key, "dynamic_part"}`).
*   **Granularity**: Decide how granular your registered services will be. One process per user? One process per major subsystem? This depends on your application's needs.
*   **Error Handling**:
    *   When looking up a service, always handle the `{:error, :not_found}` case.
    *   When registering (if not using `:via`), handle `{:error, {:already_registered, pid}}`.
*   **Testing**:
    *   Your `MyApp.Registry` module can be tested directly by spawning dummy processes and registering/looking them up.
    *   When testing services that use the registry, ensure your test setup starts the `MyApp.CoreRegistry` (often done by starting your application's supervision tree or a minimal version of it in `setup` blocks).
    *   Use `ExUnit.Case, async: true` where possible, but be mindful that tests interacting with a shared named registry might need `async: false` or a uniquely named test registry to avoid conflicts if not properly isolated. Starting the registry via `start_supervised` within each test (if `async: false`) or once per test file (`setup_all`) can help.
*   **Local vs. Distributed**:
    *   The setup above is for a **local registry** (within a single BEAM node).
    *   If you need processes to be discoverable across a cluster of BEAM nodes, you'll need a distributed registry. Popular choices:
        *   **`Horde.Registry`**: Modern, CRDT-based, well-regarded.
        *   **`pg`**: Built into Erlang/OTP, good for process groups.
        *   **`Swarm`**: Another popular option for distributed process registration and service discovery.
    *   Migrating your `MyApp.Registry` facade to use one of these would involve changing the implementation details within `MyApp.Registry` but keeping the API similar for your services.

---

### Summary of Foundation Layer Components:

1.  **`MyApp.Application`**: Starts `Registry, name: MyApp.CoreRegistry, ...}`.
2.  **`MyApp.Registry` (Facade Module)**:
    *   Provides `register/2`, `lookup/1`, `whereis/1`, `via_tuple/1`, etc.
    *   Internally uses `Registry.register(MyApp.CoreRegistry, ...)` etc.
3.  **Service Modules (e.g., `MyApp.Services.UserService`)**:
    *   `use GenServer`
    *   `start_link(args)` calls `GenServer.start_link(..., name: MyApp.Registry.via_tuple(key))`.
    *   Client functions use `GenServer.call(MyApp.Registry.via_tuple(key), ...)` or `GenServer.cast(...)`.
4.  **Supervisor Modules (e.g., `MyApp.Services.Supervisor`)**:
    *   `use DynamicSupervisor` (often)
    *   Provides functions like `start_child_service(args)` which calls `DynamicSupervisor.start_child(__MODULE__, {ServiceModule, args})`.

This structure gives you a clean, OTP-compliant, and robust way to manage and discover your application's processes and services. It relies on standard Elixir features, making it maintainable and understandable for Elixir developers.