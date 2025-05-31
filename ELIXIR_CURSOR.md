# ELIXIR_CURSOR.md

## ElixirScope Foundation Layer - Elixir Standards & Architecture

### **Project Overview**

We are building an enterprise-grade Foundation layer for ElixirScope using industry-standard Elixir patterns. This foundation serves as the rock-solid base for all subsequent layers, implementing comprehensive error handling, telemetry, configuration management, and event processing.

### **Core Architecture Principles**

#### **1. Separation of Concerns**
- **Pure Types**: `lib/foundation/types/` - Data structures only, no business logic
- **Business Logic**: `lib/foundation/logic/` - Pure functions, easily testable
- **Services**: `lib/foundation/services/` - GenServers and stateful processes  
- **Contracts**: `lib/foundation/contracts/` - Behavior definitions
- **Validation**: `lib/foundation/validation/` - Pure validation functions
- **Public APIs**: Root modules (`Config`, `Events`, etc.) - Thin wrappers over services

#### **2. OTP Supervision Strategy**
```elixir
# Application supervision tree
ElixirScope.Foundation.Application
├── ConfigServer (permanent restart)
├── EventStore (permanent restart)
├── TelemetryService (permanent restart)
└── TaskSupervisor (one_for_one)
```

#### **3. Error Handling Philosophy**
- **Never use exceptions for control flow**
- **Always return explicit result tuples for fallible operations**
- **Use behaviors and contracts to enforce consistency**
- **Provide both safe and bang! variants where appropriate**

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

# ❌ WRONG: Using exceptions for expected failures  
def read_file!(path) do
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
```

**Use `{:ok, value}` when:**
- Operation succeeds AND returns meaningful data
- Query/retrieval operations
- Transformation operations

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
```

#### **Alternative Return Patterns**

**Avoid multiple return types in single function:**
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

@spec parse_discard_rest(String.t()) :: integer() | :error  
def parse_discard_rest(string) do
  case Integer.parse(string) do
    {int, _rest} -> int
    :error -> :error
  end
end
```

### **Behaviors and Contracts**

#### **Defining Behaviors**
```elixir
defmodule ElixirScope.Foundation.Contracts.EventStore do
  @moduledoc """
  Behaviour contract for event storage implementations.
  """
  
  alias ElixirScope.Foundation.Types.{Event, Error}
  
  @callback store(Event.t()) :: {:ok, event_id()} | {:error, Error.t()}
  @callback get(event_id()) :: {:ok, Event.t()} | {:error, Error.t()}
  @callback available?() :: boolean()
  
  # Optional callbacks
  @optional_callbacks [available?: 0]
end
```

#### **Implementing Behaviors**
```elixir
defmodule ElixirScope.Foundation.Services.EventStore do
  @behaviour ElixirScope.Foundation.Contracts.EventStore
  
  # Use @impl to verify we're implementing the behavior correctly
  @impl EventStore
  def store(%Event{} = event) do
    # Implementation
  end
  
  @impl EventStore  
  def get(event_id) when is_integer(event_id) do
    # Implementation
  end
end
```

### **Protocols for Polymorphism**

```elixir
# Define protocol
defprotocol Size do
  @doc "Calculates the size of a data structure"
  def size(data)
end

# Implement for built-in types
defimpl Size, for: Map do
  def size(map), do: map_size(map)
end

defimpl Size, for: List do  
  def size(list), do: length(list)
end

# For custom structs
defmodule User do
  defstruct [:name, :email]
end

defimpl Size, for: User do
  def size(_user), do: 1
end
```

### **GenServer Patterns**

#### **Standard GenServer Structure**
```elixir
defmodule MyService do
  use GenServer
  
  # Behavior implementation (if any)
  @behaviour SomeBehaviour
  
  # Type definitions
  @type server_state :: %{key: value}
  
  ## Public API (Client Functions)
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_data(server \\ __MODULE__) do
    GenServer.call(server, :get_data)
  end
  
  ## GenServer Callbacks
  
  @impl GenServer
  def init(opts) do
    # Initialize state
    {:ok, initial_state}
  end
  
  @impl GenServer  
  def handle_call(:get_data, _from, state) do
    {:reply, {:ok, state.data}, state}
  end
  
  @impl GenServer
  def handle_cast({:update, value}, state) do
    {:noreply, %{state | data: value}}
  end
  
  @impl GenServer
  def handle_info(message, state) do
    # Handle unexpected messages gracefully
    Logger.warning("Unexpected message: #{inspect(message)}")
    {:noreply, state}
  end
end
```

#### **Service Error Handling**
```elixir
# Always check if service is available
@spec get_config(config_path()) :: {:ok, config_value()} | {:error, Error.t()}
def get_config(path) do
  case GenServer.whereis(__MODULE__) do
    nil -> create_service_error("Configuration service not started")
    _pid -> GenServer.call(__MODULE__, {:get_config, path})
  end
end

defp create_service_error(message) do
  error = Error.new(
    error_type: :service_unavailable,
    message: message,
    category: :system,
    subcategory: :initialization,
    severity: :high
  )
  {:error, error}
end
```

### **Supervision Trees**

#### **Application Module**
```elixir
defmodule ElixirScope.Foundation.Application do
  use Application
  
  @impl Application
  def start(_type, _args) do
    children = [
      # Permanent services
      {ConfigServer, name: ConfigServer},
      {EventStore, name: EventStore},
      {TelemetryService, name: TelemetryService},
      
      # Task supervisor for dynamic tasks
      {Task.Supervisor, name: ElixirScope.TaskSupervisor}
    ]
    
    opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

#### **Child Specifications**
```elixir
# Custom child spec for complex configuration
def init(:ok) do
  children = [
    # Simple child
    SomeGenServer,
    
    # Child with options
    {SomeGenServer, name: :named_server},
    
    # Child with custom restart strategy
    Supervisor.child_spec(
      {SomeGenServer, [name: :special_server]},
      restart: :permanent,
      id: :special_server
    )
  ]
  
  Supervisor.init(children, strategy: :one_for_one)
end
```

### **Pattern Matching and Guards**

#### **Assertive Pattern Matching**
```elixir
# ✅ GOOD: Explicit matching on expected patterns
case some_function(arg) do
  {:ok, value} -> handle_success(value)
  {:error, reason} -> handle_error(reason)
end

# ❌ BAD: Catch-all that hides bugs
case some_function(arg) do
  {:ok, value} -> handle_success(value)
  _ -> handle_error("unknown")  # Hides unexpected return values
end
```

#### **Guard Best Practices**
```elixir
# ✅ GOOD: Multiple when clauses for error-prone guards
def empty?(val)
    when map_size(val) == 0
    when tuple_size(val) == 0,
    do: true

# ❌ BAD: Single guard with 'or' - fails if first condition raises
def empty?(val) when map_size(val) == 0 or tuple_size(val) == 0, do: true
```

### **Testing Patterns**

#### **GenServer Testing**
```elixir
defmodule MyServiceTest do
  use ExUnit.Case, async: true
  
  # Use start_supervised! for automatic cleanup
  setup do
    service = start_supervised!(MyService)
    %{service: service}
  end
  
  test "handles requests correctly", %{service: service} do
    assert {:ok, value} = MyService.get_data(service)
    assert value == expected_value
  end
end
```

### **Documentation Standards**

#### **Module Documentation**
```elixir
defmodule ElixirScope.Foundation.Events do
  @moduledoc """
  Public API for event management and storage.
  
  Thin wrapper around EventStore that provides a clean, documented interface.
  All business logic is delegated to the service layer.
  """
  
  # Type definitions
  @type event_id :: pos_integer()
  
  # Function documentation with examples
  @doc """
  Create a new event with the given type and data.
  
  ## Examples
  
      iex> Events.new_event(:test_event, %{key: "value"})
      %Event{event_type: :test_event, data: %{key: "value"}}
      
      iex> Events.new_event(:invalid, nil)
      {:error, %Error{error_type: :invalid_event_data}}
  """
  @spec new_event(atom(), term()) :: Event.t() | {:error, Error.t()}
  def new_event(event_type, data) do
    # Implementation
  end
end
```

---

## **Current Implementation Status**

### **✅ Completed**
- [ ] Type definitions for Event, Config, Error
- [ ] Behavior contracts for EventStore, Configurable, Telemetry  
- [ ] Basic service implementations (ConfigServer, EventStore, TelemetryService)
- [ ] Logic modules with pure functions
- [ ] Public API wrappers
- [ ] Comprehensive error handling structures

### **🔧 Needs Updates Based on Standards**
- [ ] Standardize return value patterns across all modules
- [ ] Add missing typespec annotations
- [ ] Implement supervision tree properly
- [ ] Add comprehensive test coverage
- [ ] Ensure all services check availability before operations
- [ ] Standardize error creation patterns

### **📋 Next Steps**
1. Update existing code to follow these standards exactly
2. Implement proper supervision tree
3. Add comprehensive unit tests
4. Ensure 100% Dialyzer compliance
5. Add integration tests
6. Performance optimization

---

## **Key Takeaways from Elixir Documentation Review**

1. **Never use try/rescue for expected failures** - Always use explicit return tuples
2. **Be consistent with return patterns** - Don't mix `:ok` and `{:ok, value}` arbitrarily  
3. **Use behaviors extensively** - They provide contracts and enable polymorphism
4. **Implement proper supervision** - Every stateful process should be supervised
5. **Pattern match assertively** - Don't hide bugs with catch-all patterns
6. **Test with supervision in mind** - Use `start_supervised!` for automatic cleanup
7. **Document with examples** - Show both success and failure cases
8. **Type everything** - Comprehensive typespecs enable better tooling and docs 