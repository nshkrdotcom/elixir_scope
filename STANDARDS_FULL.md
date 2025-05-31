# ELIXIR_CURSOR.md

## ElixirScope Foundation Layer - Comprehensive Elixir Standards & Architecture

### **Project Overview**

We are building an enterprise-grade Foundation layer for ElixirScope using industry-standard Elixir patterns. This foundation serves as the rock-solid base for all subsequent layers, implementing comprehensive error handling, telemetry, configuration management, and event processing.

**Mission**: Create a foundation that exemplifies Elixir best practices while providing the reliability and observability required for enterprise systems.

### **Core Architecture Principles**

#### **1. Layered Architecture with Clear Boundaries**
```
┌─────────────────────────────────────┐
│ Public APIs (Config, Events, etc.) │ ← Thin wrappers, documentation
├─────────────────────────────────────┤
│ Services (GenServers, Processes)    │ ← State management, concurrency
├─────────────────────────────────────┤
│ Logic (Pure Functions)              │ ← Business rules, transformations
├─────────────────────────────────────┤
│ Validation (Pure Functions)         │ ← Data validation, constraints
├─────────────────────────────────────┤
│ Contracts (Behaviours)              │ ← Interface definitions
├─────────────────────────────────────┤
│ Types (Structs & Type Definitions)  │ ← Data structures only
└─────────────────────────────────────┘
```

#### **2. Separation of Concerns**
- **Pure Types**: `lib/foundation/types/` - Data structures only, no business logic
- **Business Logic**: `lib/foundation/logic/` - Pure functions, easily testable
- **Services**: `lib/foundation/services/` - GenServers and stateful processes  
- **Contracts**: `lib/foundation/contracts/` - Behavior definitions
- **Validation**: `lib/foundation/validation/` - Pure validation functions
- **Public APIs**: Root modules (`Config`, `Events`, etc.) - Thin wrappers over services

#### **3. OTP Supervision Strategy**
```elixir
# Application supervision tree
ElixirScope.Foundation.Application
├── ConfigServer (permanent restart)
├── EventStore (permanent restart)
├── TelemetryService (permanent restart)
├── Registry (permanent restart)
└── TaskSupervisor (one_for_one)
```

#### **4. Error Handling Philosophy**
- **Never use exceptions for control flow**
- **Always return explicit result tuples for fallible operations**
- **Use behaviors and contracts to enforce consistency**
- **Provide both safe and bang! variants where appropriate**
- **Rich error context for debugging, simple matching for control flow**

---

## **ELIXIR STANDARDS REFERENCE**

### **Return Value Conventions**

#### **The Golden Rule: Be Explicit About Success vs Failure**

```elixir
# ✅ CORRECT: Explicit success/failure tuples
@spec read_file(String.t()) :: {:ok, String.t()} | {:error, File.posix()}
def read_file(path) do
  File.read(path)  # Returns {:ok, content} or {:error, reason}
end

# ✅ CORRECT: Bang variant for when you want exceptions
@spec read_file!(String.t()) :: String.t() | no_return()
def read_file!(path) do
  case read_file(path) do
    {:ok, content} -> content
    {:error, reason} -> raise File.Error, reason: reason, action: "read file", path: path
  end
end

# ❌ WRONG: Using exceptions for expected failures in non-bang function
def read_file(path) do
  case File.read(path) do
    {:ok, content} -> content
    {:error, reason} -> raise "File error: #{reason}"
  end
end
```

#### **When to Use :ok vs {:ok, value}**

**Use `:ok` alone when:**
- Operation succeeds but returns no meaningful data
- Side-effect operations (like writing, deleting, updating)
- Initialization/setup operations
- Commands that change state

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
def initialize() do
  # Setup operation that either works or doesn't
  :ok
end

@spec delete_item(item_id()) :: :ok | {:error, Error.t()}
def delete_item(id) do
  # Delete operation - no useful return value on success
  :ok
end

@spec update_config(config_path(), config_value()) :: :ok | {:error, Error.t()}
def update_config(path, value) do
  # Update operation - success is binary
  :ok
end
```

**Use `{:ok, value}` when:**
- Operation succeeds AND returns meaningful data
- Query/retrieval operations
- Transformation operations
- Creation operations that return the created entity

```elixir
@spec get_config(config_path()) :: {:ok, config_value()} | {:error, Error.t()}
def get_config(path) do
  # Returns the actual config value on success
  {:ok, value}
end

@spec create_event(atom(), term()) :: {:ok, Event.t()} | {:error, Error.t()}
def create_event(type, data) do
  # Returns the created event on success
  {:ok, %Event{...}}
end

@spec validate_and_transform(term()) :: {:ok, validated_term()} | {:error, Error.t()}
def validate_and_transform(input) do
  # Returns transformed data on successful validation
  {:ok, transformed_input}
end
```

#### **Avoid Multiple Return Patterns**

**Don't mix return types in single function:**
```elixir
# ❌ BAD: Return type varies based on options
def parse(string, opts \\ []) do
  if Keyword.get(opts, :discard_rest) do
    case Integer.parse(string) do
      {int, _rest} -> int        # Returns integer
      :error -> :error          # Returns atom
    end
  else
    Integer.parse(string)       # Returns {integer, string} | :error
  end
end

# ✅ GOOD: Separate functions with consistent return types
@spec parse(String.t()) :: {integer(), String.t()} | :error
def parse(string), do: Integer.parse(string)

@spec parse_discard_rest(String.t()) :: {:ok, integer()} | :error  
def parse_discard_rest(string) do
  case Integer.parse(string) do
    {int, _rest} -> {:ok, int}
    :error -> :error
  end
end
```

#### **Error Return Consistency**

**Always use structured errors for rich context:**
```elixir
# ✅ PREFERRED: Rich error structure
@spec validate_config(Config.t()) :: :ok | {:error, Error.t()}
def validate_config(config) do
  case perform_validation(config) do
    :ok -> :ok
    {:error, reason} -> 
      {:error, Error.new(:validation_failed, "Config validation failed", 
                        context: %{reason: reason})}
  end
end

# ✅ ACCEPTABLE: Simple atoms for internal/low-level functions
@spec internal_check(term()) :: :ok | {:error, :invalid | :not_found}
defp internal_check(value) do
  # Internal function can use simple atoms
  if valid?(value), do: :ok, else: {:error, :invalid}
end
```

### **Behaviors and Contracts**

#### **Defining Behaviors**
```elixir
defmodule ElixirScope.Foundation.Contracts.EventStore do
  @moduledoc """
  Behaviour contract for event storage implementations.
  
  Defines the interface that all event storage backends must implement.
  This allows for different storage implementations (ETS, disk, remote) 
  while maintaining a consistent API.
  """
  
  alias ElixirScope.Foundation.Types.{Event, Error}
  
  @type event_id :: pos_integer()
  @type storage_result :: {:ok, event_id()} | {:error, Error.t()}
  @type retrieval_result :: {:ok, Event.t()} | {:error, Error.t()}
  
  @doc "Store an event and return its assigned ID"
  @callback store(Event.t()) :: storage_result()
  
  @doc "Retrieve an event by its ID"
  @callback get(event_id()) :: retrieval_result()
  
  @doc "Check if the storage backend is available"
  @callback available?() :: boolean()
  
  @doc "Get storage health and statistics"
  @callback health() :: %{status: :healthy | :degraded | :unhealthy, stats: map()}
  
  # Optional callbacks
  @optional_callbacks [available?: 0, health: 0]
end
```

#### **Implementing Behaviors**
```elixir
defmodule ElixirScope.Foundation.Services.EtsEventStore do
  @moduledoc """
  ETS-based implementation of the EventStore behavior.
  
  Provides fast in-memory event storage suitable for development 
  and testing environments.
  """
  
  @behaviour ElixirScope.Foundation.Contracts.EventStore
  
  use GenServer
  
  # Use @impl to verify we're implementing the behavior correctly
  @impl EventStore
  def store(%Event{} = event) do
    GenServer.call(__MODULE__, {:store, event})
  end
  
  @impl EventStore  
  def get(event_id) when is_integer(event_id) do
    GenServer.call(__MODULE__, {:get, event_id})
  end
  
  @impl EventStore
  def available?() do
    case GenServer.whereis(__MODULE__) do
      nil -> false
      _pid -> true
    end
  end
  
  @impl EventStore
  def health() do
    if available?() do
      GenServer.call(__MODULE__, :health)
    else
      %{status: :unhealthy, stats: %{}}
    end
  end
  
  # GenServer implementation...
end
```

### **Protocols for Polymorphism**

**Use protocols when you need polymorphism across types you don't control:**

```elixir
# Define protocol for operations that vary by data type
defprotocol ElixirScope.Foundation.Serializable do
  @doc "Serialize data to binary format"
  @spec serialize(t) :: {:ok, binary()} | {:error, term()}
  def serialize(data)
  
  @doc "Deserialize binary data back to original type"
  @spec deserialize(binary()) :: {:ok, t} | {:error, term()}
  def deserialize(binary)
end

# Implement for built-in types
defimpl ElixirScope.Foundation.Serializable, for: Map do
  def serialize(map) do
    try do
      {:ok, :erlang.term_to_binary(map)}
    rescue
      _ -> {:error, :serialization_failed}
    end
  end
  
  def deserialize(binary) when is_binary(binary) do
    try do
      {:ok, :erlang.binary_to_term(binary)}
    rescue
      _ -> {:error, :deserialization_failed}
    end
  end
end

# For custom structs
defmodule ElixirScope.Foundation.Types.Event do
  defstruct [:id, :type, :data, :timestamp]
end

defimpl ElixirScope.Foundation.Serializable, for: ElixirScope.Foundation.Types.Event do
  def serialize(%Event{} = event) do
    try do
      # Custom serialization logic for events
      data = %{
        id: event.id,
        type: event.type,
        data: event.data,
        timestamp: DateTime.to_iso8601(event.timestamp)
      }
      {:ok, Jason.encode!(data)}
    rescue
      _ -> {:error, :event_serialization_failed}
    end
  end
  
  def deserialize(binary) when is_binary(binary) do
    with {:ok, data} <- Jason.decode(binary),
         {:ok, timestamp} <- DateTime.from_iso8601(data["timestamp"]) do
      event = %Event{
        id: data["id"],
        type: String.to_atom(data["type"]),
        data: data["data"],
        timestamp: timestamp
      }
      {:ok, event}
    else
      {:error, _} -> {:error, :event_deserialization_failed}
    end
  end
end
```

### **GenServer Patterns**

#### **Standard GenServer Structure**
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServer do
  @moduledoc """
  GenServer responsible for configuration storage and validation.
  
  Provides concurrent access to configuration data with proper validation
  and change tracking. All configuration updates are validated before
  being applied.
  """
  
  use GenServer
  require Logger
  
  # Behavior implementation
  @behaviour ElixirScope.Foundation.Contracts.Configurable
  
  # Type definitions
  @type server_state :: %{
    config: Config.t(),
    last_updated: DateTime.t(),
    update_count: non_neg_integer()
  }
  
  ## Public API (Client Functions)
  
  @doc "Start the configuration server"
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc "Get current configuration"
  @spec get_config() :: {:ok, Config.t()} | {:error, Error.t()}
  def get_config(server \\ __MODULE__) do
    case GenServer.whereis(server) do
      nil -> service_unavailable_error()
      _pid -> GenServer.call(server, :get_config)
    end
  end
  
  @doc "Update configuration at specified path"
  @spec update_config(config_path(), config_value()) :: :ok | {:error, Error.t()}
  def update_config(path, value, server \\ __MODULE__) do
    case GenServer.whereis(server) do
      nil -> service_unavailable_error()
      _pid -> GenServer.call(server, {:update_config, path, value})
    end
  end
  
  ## GenServer Callbacks
  
  @impl GenServer
  def init(opts) do
    Logger.info("Starting ConfigServer")
    
    case build_initial_config(opts) do
      {:ok, config} ->
        state = %{
          config: config,
          last_updated: DateTime.utc_now(),
          update_count: 0
        }
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to initialize ConfigServer: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl GenServer  
  def handle_call(:get_config, _from, state) do
    {:reply, {:ok, state.config}, state}
  end
  
  @impl GenServer
  def handle_call({:update_config, path, value}, _from, state) do
    case validate_and_update(state.config, path, value) do
      {:ok, new_config} ->
        new_state = %{
          state | 
          config: new_config,
          last_updated: DateTime.utc_now(),
          update_count: state.update_count + 1
        }
        
        Logger.debug("Config updated at #{inspect(path)}")
        {:reply, :ok, new_state}
        
      {:error, _} = error ->
        {:reply, error, state}
    end
  end
  
  @impl GenServer
  def handle_info(message, state) do
    # Handle unexpected messages gracefully
    Logger.warning("ConfigServer received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end
  
  ## Private Functions
  
  defp service_unavailable_error do
    {:error, Error.new(:service_unavailable, "Configuration service not started")}
  end
  
  defp build_initial_config(opts) do
    # Implementation details...
  end
  
  defp validate_and_update(config, path, value) do
    # Implementation details...
  end
end
```

#### **Service Availability Patterns**
```elixir
# Always check if service is available before operations
@spec get_config(config_path()) :: {:ok, config_value()} | {:error, Error.t()}
def get_config(path) do
  with {:ok, service} <- ensure_service_available(),
       {:ok, value} <- GenServer.call(service, {:get_config, path}) do
    {:ok, value}
  end
end

@spec ensure_service_available() :: {:ok, pid()} | {:error, Error.t()}
defp ensure_service_available do
  case GenServer.whereis(__MODULE__) do
    nil -> 
      {:error, Error.new(:service_unavailable, "Service not started", 
                        context: %{service: __MODULE__})}
    pid -> 
      {:ok, pid}
  end
end
```

### **Supervision Trees and Fault Tolerance**

#### **Application Module**
```elixir
defmodule ElixirScope.Foundation.Application do
  @moduledoc """
  Application entry point for ElixirScope Foundation layer.
  
  Manages the supervision tree and ensures proper startup/shutdown
  of all foundation services.
  """
  
  use Application
  require Logger
  
  @impl Application
  def start(_type, _args) do
    Logger.info("Starting ElixirScope Foundation Application")
    
    children = [
      # Core services - these should restart if they fail
      {ElixirScope.Foundation.Services.ConfigServer, []},
      {ElixirScope.Foundation.Services.EventStore, []},
      {ElixirScope.Foundation.Services.TelemetryService, []},
      
      # Registry for dynamic process management
      {Registry, keys: :unique, name: ElixirScope.Foundation.Registry},
      
      # Task supervisor for background tasks
      {Task.Supervisor, name: ElixirScope.Foundation.TaskSupervisor},
      
      # Metrics collection (if using telemetry_metrics)
      ElixirScope.Foundation.Telemetry.Supervisor
    ]
    
    # Use one_for_one strategy - if one child fails, only restart that child
    opts = [
      strategy: :one_for_one, 
      name: ElixirScope.Foundation.Supervisor,
      max_restarts: 3,
      max_seconds: 5
    ]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("ElixirScope Foundation Application started successfully")
        {:ok, pid}
        
      {:error, reason} ->
        Logger.error("Failed to start ElixirScope Foundation Application: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @impl Application
  def stop(_state) do
    Logger.info("Stopping ElixirScope Foundation Application")
    :ok
  end
end
```

#### **Custom Child Specifications**
```elixir
defmodule ElixirScope.Foundation.Services.EventStore do
  use GenServer
  
  # Custom child spec for more control
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,  # Always restart if it crashes
      shutdown: 5000,       # Give it 5 seconds to shut down gracefully
      type: :worker         # This is a worker, not a supervisor
    }
  end
  
  # Alternative: use default child spec with modifications
  def child_spec(opts) do
    super(opts)
    |> Map.put(:restart, :permanent)
    |> Map.put(:shutdown, 10_000)  # Longer shutdown for cleanup
  end
end
```

### **Pattern Matching and Guards**

#### **Assertive Pattern Matching**
```elixir
# ✅ GOOD: Explicit matching on expected patterns
case ConfigServer.get_config(path) do
  {:ok, value} -> 
    process_config_value(value)
  {:error, %Error{error_type: :not_found}} -> 
    handle_missing_config(path)
  {:error, %Error{error_type: :service_unavailable}} -> 
    handle_service_down()
  {:error, error} -> 
    handle_unexpected_error(error)
end

# ❌ BAD: Catch-all that hides bugs
case ConfigServer.get_config(path) do
  {:ok, value} -> process_config_value(value)
  _ -> handle_error("unknown")  # Hides unexpected return values
end
```

#### **Guard Best Practices**
```elixir
# ✅ GOOD: Multiple when clauses for error-prone guards
def empty?(val)
    when is_map(val) and map_size(val) == 0,
    do: true

def empty?(val)
    when is_tuple(val) and tuple_size(val) == 0,
    do: true

def empty?(val)
    when is_list(val) and length(val) == 0,
    do: true
    
def empty?(_), do: false

# ❌ BAD: Single guard with 'or' - fails if first condition raises
def empty?(val) when map_size(val) == 0 or tuple_size(val) == 0, do: true

# ✅ GOOD: Custom guard for common patterns
defguard is_config_path(path) 
  when is_list(path) and length(path) > 0

defguard is_valid_event_type(type) 
  when is_atom(type) and type != nil

def update_config(path, value) 
    when is_config_path(path) do
  # Implementation
end
```

### **Testing Patterns**

#### **Test Organization**
```elixir
# Test structure mirrors module structure
test/
├── unit/
│   ├── foundation/
│   │   ├── types/
│   │   ├── logic/
│   │   ├── validation/
│   │   └── services/
│   └── integration/
├── contract/           # Behavior implementation tests
├── property/          # Property-based tests
├── smoke/            # High-level smoke tests
└── support/          # Test helpers and fixtures
```

#### **GenServer Testing**
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServerTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Foundation.Services.ConfigServer
  alias ElixirScope.Foundation.Types.{Config, Error}
  
  # Use start_supervised! for automatic cleanup
  setup do
    server = start_supervised!(ConfigServer)
    %{server: server}
  end
  
  describe "configuration retrieval" do
    test "returns current configuration", %{server: server} do
      assert {:ok, %Config{}} = ConfigServer.get_config(server)
    end
    
    test "handles service unavailable gracefully" do
      # Stop the server
      GenServer.stop(server)
      
      # Should return proper error
      assert {:error, %Error{error_type: :service_unavailable}} = 
               ConfigServer.get_config(server)
    end
  end
  
  describe "configuration updates" do
    test "updates valid configuration paths", %{server: server} do
      path = [:ai, :planning, :sampling_rate]
      value = 0.8
      
      assert :ok = ConfigServer.update_config(path, value, server)
      assert {:ok, config} = ConfigServer.get_config(server)
      assert get_in(config, path) == value
    end
    
    test "rejects invalid configuration paths", %{server: server} do
      path = [:nonexistent, :path]
      value = "anything"
      
      assert {:error, %Error{error_type: :invalid_path}} = 
               ConfigServer.update_config(path, value, server)
    end
  end
end
```

#### **Contract Testing with Behaviours**
```elixir
defmodule ElixirScope.Foundation.Contracts.EventStoreContractTest do
  @moduledoc """
  Contract test that verifies any EventStore implementation
  behaves correctly according to the behavior specification.
  """
  
  use ExUnit.Case
  
  # Test against all implementations
  @implementations [
    ElixirScope.Foundation.Services.EtsEventStore,
    ElixirScope.Foundation.Services.DiskEventStore
  ]
  
  for implementation <- @implementations do
    @implementation implementation
    
    describe "#{@implementation} contract compliance" do
      setup do
        # Start the implementation
        store = start_supervised!(@implementation)
        %{store: store}
      end
      
      test "stores and retrieves events correctly", %{store: store} do
        event = create_test_event()
        
        # Store event
        assert {:ok, event_id} = @implementation.store(event)
        assert is_integer(event_id)
        
        # Retrieve event
        assert {:ok, retrieved_event} = @implementation.get(event_id)
        assert retrieved_event.type == event.type
        assert retrieved_event.data == event.data
      end
      
      test "reports availability correctly", %{store: _store} do
        assert @implementation.available?() == true
        
        # Stop the service
        GenServer.stop(@implementation)
        
        assert @implementation.available?() == false
      end
    end
  end
  
  defp create_test_event do
    %Event{
      type: :test_event,
      data: %{test: "data"},
      timestamp: DateTime.utc_now()
    }
  end
end
```

#### **Property-Based Testing**
```elixir
defmodule ElixirScope.Foundation.Logic.ConfigValidationPropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  alias ElixirScope.Foundation.Logic.ConfigValidation
  
  property "validation is consistent" do
    check all config <- config_generator() do
      # Validation should be deterministic
      result1 = ConfigValidation.validate(config)
      result2 = ConfigValidation.validate(config)
      
      assert result1 == result2
    end
  end
  
  property "valid configs always pass validation" do
    check all config <- valid_config_generator() do
      assert :ok = ConfigValidation.validate(config)
    end
  end
  
  property "invalid configs always fail validation" do
    check all config <- invalid_config_generator() do
      assert {:error, _} = ConfigValidation.validate(config)
    end
  end
  
  # Generators
  defp config_generator do
    gen all ai_config <- ai_config_generator(),
            capture_config <- capture_config_generator() do
      %Config{ai: ai_config, capture: capture_config}
    end
  end
  
  defp valid_config_generator do
    # Generate only valid configurations
  end
  
  defp invalid_config_generator do
    # Generate configurations with known invalid data
  end
end
```

### **Documentation Standards**

#### **Module Documentation**
```elixir
defmodule ElixirScope.Foundation.Events do
  @moduledoc """
  Public API for event management and storage.
  
  This module provides a clean, documented interface for creating, storing,
  and retrieving events. All business logic is delegated to the service layer,
  making this module a thin wrapper that focuses on API design and documentation.
  
  ## Architecture
  
  The Events module follows the foundation's layered architecture:
  
  - **Public API** (this module): Clean interface with comprehensive docs
  - **Service Layer**: EventStore GenServer handling state and concurrency  
  - **Logic Layer**: Pure functions for event processing and validation
  - **Types Layer**: Event struct definitions and type specifications
  
  ## Error Handling
  
  All functions return explicit result tuples following Elixir conventions:
  
  - `{:ok, result}` for successful operations that return data
  - `:ok` for successful operations that don't return meaningful data
  - `{:error, Error.t()}` for all failures with structured error information
  
  ## Examples
  
  Basic event creation and storage:
  
      iex> Events.new_event(:user_login, %{user_id: 123, ip: "192.168.1.1"})
      {:ok, %Event{id: 1, type: :user_login, data: %{user_id: 123, ip: "192.168.1.1"}}}
      
      iex> Events.get_event(1)
      {:ok, %Event{id: 1, type: :user_login, data: %{user_id: 123, ip: "192.168.1.1"}}}
  
  Error handling:
  
      iex> Events.new_event(nil, %{})
      {:error, %Error{error_type: :invalid_event_type, message: "Event type cannot be nil"}}
      
      iex> Events.get_event(999)
      {:error, %Error{error_type: :not_found, message: "Event not found"}}
  """
  
  alias ElixirScope.Foundation.Types.{Event, Error}
  alias ElixirScope.Foundation.Services.EventStore
  
  # Type definitions for this module's API
  @type event_id :: pos_integer()
  @type event_type :: atom()
  @type event_data :: term()
  @type creation_result :: {:ok, Event.t()} | {:error, Error.t()}
  @type retrieval_result :: {:ok, Event.t()} | {:error, Error.t()}
  
  @doc """
  Create a new event with the given type and data.
  
  Events are immutable records of things that happened in the system.
  Each event gets a unique ID and timestamp when created.
  
  ## Parameters
  
  - `event_type` - Atom identifying the type of event (e.g., `:user_login`, `:config_updated`)
  - `event_data` - Arbitrary data associated with the event (must be serializable)
  
  ## Returns
  
  - `{:ok, Event.t()}` - Successfully created event with assigned ID
  - `{:error, Error.t()}` - Creation failed with detailed error information
  
  ## Examples
  
      iex> Events.new_event(:test_event, %{key: "value"})
      {:ok, %Event{id: 1, type: :test_event, data: %{key: "value"}}}
      
      iex> Events.new_event(:invalid, nil)
      {:error, %Error{error_type: :invalid_event_data}}
      
      # Large data is automatically handled
      iex> large_data = String.duplicate("x", 10_000)
      iex> Events.new_event(:large_event, large_data)
      {:ok, %Event{id: 2, type: :large_event, data: {:truncated, 10000, "binary data"}}}
  """
  @spec new_event(event_type(), event_data()) :: creation_result()
  def new_event(event_type, data) when is_atom(event_type) do
    EventStore.create_event(event_type, data)
  end
  
  def new_event(event_type, _data) do
    {:error, Error.new(:invalid_event_type, 
                      "Event type must be an atom, got: #{inspect(event_type)}")}
  end
  
  @doc """
  Retrieve an event by its unique ID.
  
  ## Parameters
  
  - `event_id` - Positive integer ID of the event to retrieve
  
  ## Returns
  
  - `{:ok, Event.t()}` - Event found and returned
  - `{:error, Error.t()}` - Event not found or other error
  
  ## Examples
  
      iex> Events.get_event(1)
      {:ok, %Event{id: 1, type: :user_login, data: %{user_id: 123}}}
      
      iex> Events.get_event(999)
      {:error, %Error{error_type: :not_found, message: "Event 999 not found"}}
      
      iex> Events.get_event(-1)
      {:error, %Error{error_type: :invalid_event_id, message: "Event ID must be positive"}}
  """
  @spec get_event(event_id()) :: retrieval_result()
  def get_event(event_id) when is_integer(event_id) and event_id > 0 do
    EventStore.get_event(event_id)
  end
  
  def get_event(event_id) do
    {:error, Error.new(:invalid_event_id, 
                      "Event ID must be a positive integer, got: #{inspect(event_id)}")}
  end
end
```

#### **Function Documentation Template**
```elixir
@doc """
One-line summary of what the function does.

Optional longer description that explains the purpose, behavior,
and any important details about the function.

## Parameters

- `param1` - Description of first parameter with type info
- `param2` - Description of second parameter (optional: default behavior)

## Returns

- `{:ok, result}` - Success case description
- `{:error, Error.t()}` - Failure case description
- `:ok` - Success case for commands (if applicable)

## Examples

    iex> MyModule.my_function(valid_input)
    {:ok, expected_result}
    
    iex> MyModule.my_function(invalid_input)
    {:error, %Error{error_type: :invalid_input}}

## See Also

- `related_function/2` - For related functionality
- `ElixirScope.Foundation.Types.SomeType` - For type definitions
"""
```

### **Error Handling Standards**

#### **Error Structure Design**
```elixir
defmodule ElixirScope.Foundation.Types.Error do
  @moduledoc """
  Comprehensive error structure for the ElixirScope foundation.
  
  Provides rich error context while maintaining pattern matching simplicity.
  """
  
  @type error_category :: :config | :system | :data | :external | :validation
  @type error_severity :: :low | :medium | :high | :critical
  @type error_code :: atom()
  
  defstruct [
    # Core identification
    :error_type,           # Atom for pattern matching (:not_found, :invalid_input)
    :message,              # Human-readable error message
    :code,                 # Numeric code for monitoring/alerting
    
    # Classification
    :category,             # High-level category (:config, :system, :data)
    :severity,             # Impact level (:low, :medium, :high, :critical)
    
    # Context and debugging
    :context,              # Map with relevant data for debugging
    :stacktrace,           # Optional stacktrace for internal errors
    :correlation_id,       # For request tracing
    :timestamp,            # When the error occurred
    
    # Recovery and monitoring
    :retry_strategy,       # How this error should be handled (:retry, :no_retry)
    :recovery_suggestions  # List of potential fixes
  ]
  
  @type t :: %__MODULE__{
    error_type: error_code(),
    message: String.t(),
    code: pos_integer(),
    category: error_category(),
    severity: error_severity(),
    context: map(),
    stacktrace: list() | nil,
    correlation_id: String.t() | nil,
    timestamp: DateTime.t(),
    retry_strategy: atom(),
    recovery_suggestions: [String.t()]
  }
end
```

#### **Error Creation Patterns**
```elixir
# ✅ GOOD: Consistent error creation with context
def validate_config(%Config{ai: nil}) do
  {:error, Error.new(
    error_type: :missing_required_section,
    message: "AI configuration section is required",
    category: :validation,
    severity: :high,
    context: %{
      missing_section: :ai,
      available_sections: [:capture, :storage, :interface]
    }
  )}
end

# ✅ GOOD: Helper functions for common error patterns
defp validation_error(field, reason, context \\ %{}) do
  Error.new(
    error_type: :validation_failed,
    message: "Validation failed for field '#{field}': #{reason}",
    category: :validation,
    severity: :medium,
    context: Map.merge(%{field: field, reason: reason}, context)
  )
end

# ✅ GOOD: Pattern matching on error types
case SomeModule.operation() do
  {:ok, result} -> 
    handle_success(result)
    
  {:error, %Error{error_type: :not_found} = error} -> 
    handle_not_found(error)
    
  {:error, %Error{error_type: :validation_failed} = error} -> 
    handle_validation_error(error)
    
  {:error, %Error{severity: :critical} = error} -> 
    escalate_critical_error(error)
    
  {:error, error} -> 
    handle_unexpected_error(error)
end
```

### **Performance and Monitoring Standards**

#### **Telemetry Integration**
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServer do
  use GenServer
  
  # Emit telemetry events for monitoring
  @impl GenServer
  def handle_call({:update_config, path, value}, _from, state) do
    start_time = System.monotonic_time()
    
    result = case validate_and_update(state.config, path, value) do
      {:ok, new_config} ->
        new_state = %{state | config: new_config, update_count: state.update_count + 1}
        
        # Emit success telemetry
        :telemetry.execute(
          [:elixir_scope, :config, :update, :success],
          %{duration: System.monotonic_time() - start_time},
          %{path: path, update_count: state.update_count + 1}
        )
        
        {:ok, new_state}
        
      {:error, error} ->
        # Emit failure telemetry
        :telemetry.execute(
          [:elixir_scope, :config, :update, :error],
          %{duration: System.monotonic_time() - start_time},
          %{path: path, error_type: error.error_type, severity: error.severity}
        )
        
        {:error, error}
    end
    
    case result do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end
end
```

#### **Memory and Resource Management**
```elixir
defmodule ElixirScope.Foundation.Services.EventStore do
  use GenServer
  
  # Periodic cleanup to prevent memory leaks
  @cleanup_interval :timer.minutes(5)
  @max_events 100_000
  
  @impl GenServer
  def init(opts) do
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)
    
    state = %{
      events: %{},
      event_count: 0,
      last_cleanup: DateTime.utc_now()
    }
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_info(:cleanup, state) do
    # Perform cleanup if needed
    new_state = if state.event_count > @max_events do
      cleanup_old_events(state)
    else
      state
    end
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)
    
    # Emit memory usage metrics
    :telemetry.execute(
      [:elixir_scope, :event_store, :memory],
      %{event_count: new_state.event_count, memory_usage: :erlang.memory(:total)},
      %{cleanup_performed: new_state != state}
    )
    
    {:noreply, %{new_state | last_cleanup: DateTime.utc_now()}}
  end
  
  defp cleanup_old_events(state) do
    # Keep only the most recent events
    events_to_keep = @max_events * 0.8 |> round()
    
    sorted_events = state.events
    |> Enum.sort_by(fn {_id, event} -> event.timestamp end, :desc)
    |> Enum.take(events_to_keep)
    |> Enum.into(%{})
    
    %{state | events: sorted_events, event_count: map_size(sorted_events)}
  end
end
```

### **Dependency Injection and Testing**

#### **Dependency Injection Patterns**
```elixir
defmodule ElixirScope.Foundation.Logic.EventProcessor do
  @moduledoc """
  Pure business logic for event processing.
  
  Takes dependencies as parameters to enable easy testing
  and different implementations.
  """
  
  @type event_store :: module()
  @type telemetry_service :: module()
  
  @doc "Process an event using the provided dependencies"
  @spec process_event(Event.t(), event_store(), telemetry_service()) :: 
    {:ok, Event.t()} | {:error, Error.t()}
  def process_event(event, event_store \\ EventStore, telemetry \\ TelemetryService) do
    with {:ok, validated_event} <- validate_event(event),
         {:ok, event_id} <- event_store.store(validated_event),
         :ok <- telemetry.emit_counter([:events, :processed]) do
      {:ok, %{validated_event | id: event_id}}
    end
  end
  
  # Pure validation function - no dependencies
  defp validate_event(%Event{type: nil}), do: {:error, Error.new(:invalid_event_type)}
  defp validate_event(%Event{} = event), do: {:ok, event}
end

# In tests:
defmodule EventProcessorTest do
  use ExUnit.Case
  
  import Mox
  
  # Define mocks
  defmock(MockEventStore, for: ElixirScope.Foundation.Contracts.EventStore)
  defmock(MockTelemetry, for: ElixirScope.Foundation.Contracts.Telemetry)
  
  test "processes valid events successfully" do
    event = %Event{type: :test, data: %{}}
    
    # Set up expectations
    MockEventStore
    |> expect(:store, fn ^event -> {:ok, 123} end)
    
    MockTelemetry
    |> expect(:emit_counter, fn [:events, :processed] -> :ok end)
    
    # Test with mocked dependencies
    assert {:ok, processed_event} = 
      EventProcessor.process_event(event, MockEventStore, MockTelemetry)
    
    assert processed_event.id == 123
  end
end
```

### **Configuration Management Patterns**

#### **Environment-Specific Configuration**
```elixir
# config/config.exs
import Config

config :elixir_scope, :foundation,
  # Core configuration that rarely changes
  max_event_size: 1_048_576,  # 1MB
  telemetry_buffer_size: 1000

# Runtime configuration
config :elixir_scope, ElixirScope.Foundation.Services.ConfigServer,
  validation_level: :strict,
  allow_runtime_updates: true

# Import environment-specific config
import_config "#{config_env()}.exs"

# config/dev.exs
import Config

config :elixir_scope, ElixirScope.Foundation.Services.ConfigServer,
  validation_level: :permissive,  # Allow more flexibility in dev
  debug_mode: true

config :elixir_scope, ElixirScope.Foundation.Services.EventStore,
  storage_backend: :ets,  # Fast in-memory storage for dev
  cleanup_interval: :timer.minutes(1)  # More frequent cleanup

# config/prod.exs
import Config

config :elixir_scope, ElixirScope.Foundation.Services.ConfigServer,
  validation_level: :strict,
  allow_runtime_updates: false  # Prevent runtime changes in prod

config :elixir_scope, ElixirScope.Foundation.Services.EventStore,
  storage_backend: :persistent_term,  # Production storage
  cleanup_interval: :timer.minutes(30)
```

#### **Runtime Configuration Validation**
```elixir
defmodule ElixirScope.Foundation.Logic.ConfigValidation do
  @moduledoc """
  Configuration validation logic with environment-aware rules.
  """
  
  @doc "Validate configuration based on current environment and rules"
  @spec validate(Config.t(), keyword()) :: :ok | {:error, Error.t()}
  def validate(config, opts \\ []) do
    env = Keyword.get(opts, :env, Application.get_env(:elixir_scope, :env, :dev))
    validation_level = Keyword.get(opts, :validation_level, :normal)
    
    with :ok <- validate_required_fields(config),
         :ok <- validate_value_constraints(config, validation_level),
         :ok <- validate_environment_specific(config, env) do
      :ok
    end
  end
  
  # Different validation rules for different environments
  defp validate_environment_specific(config, :prod) do
    # Strict validation for production
    with :ok <- validate_security_settings(config),
         :ok <- validate_performance_settings(config),
         :ok <- validate_monitoring_settings(config) do
      :ok
    end
  end
  
  defp validate_environment_specific(_config, :dev) do
    # Relaxed validation for development
    :ok
  end
  
  defp validate_environment_specific(config, :test) do
    # Test-specific validation
    validate_test_safety(config)
  end
end
```

---

## **Enterprise Patterns and Advanced Concepts**

### **Circuit Breaker Pattern**
```elixir
defmodule ElixirScope.Foundation.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for protecting against cascading failures.
  """
  
  use GenServer
  
  @type state :: :closed | :open | :half_open
  @type circuit_config :: %{
    failure_threshold: pos_integer(),
    recovery_timeout: pos_integer(),
    success_threshold: pos_integer()
  }
  
  defstruct [
    :name,
    :state,
    :failure_count,
    :success_count,
    :last_failure_time,
    :config
  ]
  
  def call(circuit_name, fun) when is_function(fun, 0) do
    case GenServer.call(circuit_name, :get_state) do
      :closed -> 
        execute_with_monitoring(circuit_name, fun)
      :open -> 
        {:error, :circuit_open}
      :half_open -> 
        execute_with_recovery_monitoring(circuit_name, fun)
    end
  end
  
  defp execute_with_monitoring(circuit_name, fun) do
    try do
      result = fun.()
      GenServer.cast(circuit_name, :success)
      result
    rescue
      error ->
        GenServer.cast(circuit_name, :failure)
        {:error, error}
    end
  end
end
```

### **Saga Pattern for Distributed Transactions**
```elixir
defmodule ElixirScope.Foundation.Saga do
  @moduledoc """
  Saga pattern implementation for coordinating distributed operations.
  """
  
  @type step :: {module(), atom(), [term()]}
  @type compensation :: {module(), atom(), [term()]}
  @type saga_step :: {step(), compensation()}
  
  @doc "Execute a saga with automatic compensation on failure"
  @spec execute([saga_step()]) :: {:ok, [term()]} | {:error, term()}
  def execute(steps) do
    execute_steps(steps, [], [])
  end
  
  defp execute_steps([], completed, _compensations) do
    {:ok, Enum.reverse(completed)}
  end
  
  defp execute_steps([{step, compensation} | rest], completed, compensations) do
    case execute_step(step) do
      {:ok, result} ->
        execute_steps(rest, [result | completed], [compensation | compensations])
        
      {:error, reason} ->
        # Execute compensations in reverse order
        compensate(compensations, completed)
        {:error, reason}
    end
  end
  
  defp execute_step({module, function, args}) do
    apply(module, function, args)
  end
  
  defp compensate(compensations, completed_results) do
    compensations
    |> Enum.zip(completed_results)
    |> Enum.each(fn {{module, function, args}, result} ->
      apply(module, function, args ++ [result])
    end)
  end
end
```

### **Event Sourcing Foundation**
```elixir
defmodule ElixirScope.Foundation.EventSourcing do
  @moduledoc """
  Event sourcing primitives for audit trails and state reconstruction.
  """
  
  @type aggregate_id :: String.t()
  @type event_stream :: [Event.t()]
  @type snapshot :: %{aggregate_id: aggregate_id(), version: pos_integer(), state: term()}
  
  @doc "Apply events to reconstruct aggregate state"
  @spec reconstruct_state(aggregate_id(), module()) :: {:ok, term()} | {:error, Error.t()}
  def reconstruct_state(aggregate_id, aggregate_module) do
    with {:ok, events} <- get_event_stream(aggregate_id),
         {:ok, snapshot} <- get_latest_snapshot(aggregate_id),
         events_after_snapshot <- filter_events_after_snapshot(events, snapshot) do
      
      initial_state = snapshot_state(snapshot)
      final_state = apply_events(events_after_snapshot, initial_state, aggregate_module)
      
      {:ok, final_state}
    end
  end
  
  @doc "Create snapshot for performance optimization"
  @spec create_snapshot(aggregate_id(), term(), pos_integer()) :: :ok | {:error, Error.t()}
  def create_snapshot(aggregate_id, state, version) do
    snapshot = %{
      aggregate_id: aggregate_id,
      version: version,
      state: state,
      created_at: DateTime.utc_now()
    }
    
    SnapshotStore.save(snapshot)
  end
  
  defp apply_events(events, initial_state, aggregate_module) do
    Enum.reduce(events, initial_state, fn event, state ->
      aggregate_module.apply_event(state, event)
    end)
  end
end
```

---

## **Current Implementation Status & Migration Plan**

### **✅ Well-Implemented (Keep As-Is)**
- [x] Comprehensive Error structure with rich context
- [x] ErrorContext for operation tracking
- [x] Basic GenServer patterns
- [x] Telemetry integration foundation
- [x] Test structure organization

### **🔧 Needs Updates to Match Standards**

#### **High Priority (Foundation Stability)**
1. **Return Value Consistency**
   - Standardize all APIs to use `{:ok, value} | {:error, Error.t()}` pattern
   - Remove mixed return types (`:ok` vs `{:ok, value}` inconsistency)
   - Update all tests to expect consistent return patterns

2. **Service Availability Checks**
   - Add `ensure_service_available/0` pattern to all service APIs
   - Implement graceful degradation when services are unavailable
   - Add health check endpoints for monitoring

3. **Behavior Contracts**
   - Define behaviors for all major interfaces (Configurable, EventStore, Telemetry)
   - Implement contract tests to verify behavior compliance
   - Add typespec coverage for all behavior callbacks

#### **Medium Priority (Enterprise Patterns)**
4. **Supervision Tree Enhancement**
   - Implement proper Application module with supervision strategy
   - Add Registry for process discovery
   - Implement TaskSupervisor for background work

5. **Dependency Injection**
   - Refactor logic modules to accept dependencies as parameters
   - Create mock implementations for testing
   - Add configuration for swapping implementations

6. **Performance Monitoring**
   - Add comprehensive telemetry events throughout the system
   - Implement memory usage monitoring and cleanup
   - Add performance metrics collection

#### **Low Priority (Advanced Features)**
7. **Circuit Breaker Integration**
   - Add circuit breaker protection for external dependencies
   - Implement automatic recovery mechanisms
   - Add monitoring for circuit breaker state changes

8. **Event Sourcing Preparation**
   - Design event store for append-only operations
   - Add event versioning and migration support
   - Implement snapshot support for performance

---

## **Migration Strategy**

### **Phase 1: Foundation Stabilization (Week 1-2)**
1. Fix return value inconsistencies across all modules
2. Add behavior contracts and update implementations
3. Implement proper service availability checking
4. Update all tests to match new contracts

### **Phase 2: Architecture Enhancement (Week 3-4)**
1. Implement proper supervision tree
2. Add dependency injection to logic modules
3. Create comprehensive contract tests
4. Add performance monitoring and telemetry

### **Phase 3: Enterprise Features (Week 5-6)**
1. Add circuit breaker protection
2. Implement advanced error recovery patterns
3. Add event sourcing capabilities
4. Performance optimization and monitoring

### **Phase 4: Documentation and Validation (Week 7-8)**
1. Complete comprehensive documentation with examples
2. Add property-based testing
3. Performance benchmarking and optimization
4. Security review and hardening

---

## **Key Quality Gates**

### **Code Quality Standards**
- [ ] 100% Dialyzer compliance with comprehensive typespecs
- [ ] 95%+ test coverage with meaningful assertions
- [ ] All public functions have comprehensive documentation with examples
- [ ] All modules follow consistent error handling patterns
- [ ] Zero compiler warnings

### **Performance Standards**
- [ ] Service startup time < 100ms
- [ ] API response time < 10ms for simple operations
- [ ] Memory usage stable under load (no leaks)
- [ ] Graceful degradation under high concurrency

### **Reliability Standards**
- [ ] All services handle crashes gracefully with supervision
- [ ] Circuit breakers protect against cascading failures
- [ ] Comprehensive error logging and telemetry
- [ ] Zero data loss under normal failure scenarios

### **Maintainability Standards**
- [ ] Clear separation between pure and impure functions
- [ ] Dependency injection enables easy testing and swapping
- [ ] Behavior contracts enable polymorphism
- [ ] Comprehensive integration and contract tests

This comprehensive standards document provides the foundation for building enterprise-grade Elixir applications that follow canonical patterns while maintaining the flexibility and power that makes Elixir unique.