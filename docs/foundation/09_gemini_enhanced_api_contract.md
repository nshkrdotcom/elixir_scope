Okay, let's break down the integration of the planned Infrastructure Layer into the ElixirScope Foundation Layer (Layer 1), clarify how existing registries are used, and define the updated API contract for this enhanced Foundation Layer.

You're right to seek clarity. The "Infrastructure Layer" as described in `10_gemini_plan.md` isn't a separate, higher/lower layer in the 9-layer model; rather, it's a **new set of components *within* the Foundation Layer (L1)**, residing in `lib/elixir_scope/foundation/infrastructure/`. These components provide common resilience and resource management patterns that will be used by other Foundation services (like `ConfigServer`, `EventStore`) and potentially by higher layers if they need direct access (though typically they'd go through a Foundation facade).

The AST layer documents (`REQ-*.md`, `SUPERVISION_TREE.md`, etc.) describe Layer 2. Layer 2 consumes Layer 1 (Foundation). So, by enhancing Layer 1 with this new Infrastructure sub-layer, Layer 2 indirectly benefits from a more resilient and performant foundation. Layer 2 itself would generally *not* directly call, for example, `ElixirScope.Foundation.Infrastructure.CircuitBreakerWrapper.execute/3`. Instead, it would call a Layer 1 service (e.g., `ElixirScope.Foundation.Events.store/1`), and *that service's implementation* would use the infrastructure components for its own internal operations (like protecting a database write with a circuit breaker).

Here's the technical document unpacking this:

---

## ElixirScope Foundation Layer: Enhanced API Contract & Infrastructure Integration

**Document Version:** 1.1 (Incorporating Infrastructure Layer)
**Date:** May 2025
**Status:** Proposed Design Specification

**Table of Contents:**
1.  [Introduction & Goals](#1-introduction--goals)
2.  [Infrastructure Layer Integration within Foundation](#2-infrastructure-layer-integration-within-foundation)
    -   2.1. Role and Placement
    -   2.2. Consumption by Existing Foundation Services
3.  [Role of Registries (`ProcessRegistry`, `ServiceRegistry`)](#3-role-of-registries-processregistry-serviceregistry)
    -   3.1. `ProcessRegistry`
    -   3.2. `ServiceRegistry`
    -   3.3. Infrastructure Component Naming & Registration
4.  [Updated Foundation Layer API Contract](#4-updated-foundation-layer-api-contract)
    -   4.1. Existing Public Facades (Unchanged for External Consumers)
        -   `ElixirScope.Foundation`
        -   `ElixirScope.Foundation.Config`
        -   `ElixirScope.Foundation.Events`
        -   `ElixirScope.Foundation.Telemetry`
        -   `ElixirScope.Foundation.Error` & `ElixirScope.Foundation.Types.*`
    -   4.2. New Infrastructure Facade & Wrappers API
        -   `ElixirScope.Foundation.Infrastructure`
        -   `ElixirScope.Foundation.Infrastructure.CircuitBreakerWrapper`
        -   `ElixirScope.Foundation.Infrastructure.RateLimiter`
        -   `ElixirScope.Foundation.Infrastructure.ConnectionManager`
    -   4.3. Future Custom Infrastructure Services API (Preview)
        -   `ElixirScope.Foundation.Infrastructure.PerformanceMonitor`
        -   `ElixirScope.Foundation.Infrastructure.MemoryManager`
        -   `ElixirScope.Foundation.Infrastructure.HealthAggregator`
5.  [Supervision Strategy for Infrastructure Components](#5-supervision-strategy-for-infrastructure-components)
6.  [Configuration and Observability](#6-configuration-and-observability)

---

### 1. Introduction & Goals

This document defines the updated API contract and integration strategy for the ElixirScope Foundation Layer (L1), incorporating the new "Infrastructure Sub-Layer" as detailed in `docs/FOUNDATION_OTP_IMPLEMENT_NOW/10_gemini_plan.md`.

The primary goals of this specification are:
*   Clarify how the new infrastructure components (Circuit Breaker, Rate Limiter, Connection Pool wrappers, and future custom services) fit within the existing Foundation Layer.
*   Define how existing Foundation services (`ConfigServer`, `EventStore`, `TelemetryService`) and registries will interact with or utilize these new infrastructure capabilities.
*   Provide a clear, defined public API for the enhanced Foundation Layer, including the new infrastructure components.
*   Ensure that this enhancement maintains the CMM Level 4 maturity and architectural integrity of the Foundation.

---

### 2. Infrastructure Layer Integration within Foundation

#### 2.1. Role and Placement

The "Infrastructure Layer" described in `10_gemini_plan.md` is **not a distinct numbered layer** in the 9-layer ElixirScope architecture. Instead, it is a **new sub-component or sub-layer *within* the existing Foundation Layer (Layer 1)**.
*   **Directory:** `lib/elixir_scope/foundation/infrastructure/`
*   **Purpose:** To provide common, reusable infrastructure patterns (resilience, resource management) that can be consumed by:
    *   Other services within the Foundation Layer itself (e.g., `EventStore` using a connection pool and circuit breaker for its database).
    *   Higher layers (AST, CPG, etc.) *if* they have direct needs for such patterns that are not already encapsulated by a Foundation service. However, the primary consumption model is *internal* to L1 services.

#### 2.2. Consumption by Existing Foundation Services

The existing core Foundation services (`ConfigServer`, `EventStore`, `TelemetryService`) will be the primary internal consumers of the new infrastructure components.

**Example Scenario:** `ElixirScope.Foundation.Services.EventStore` needs to write an event to a persistent database (as per future roadmap Initiative 1.3 & 2.1).
*   **Without Infrastructure Layer:** `EventStore` would directly manage DB connection logic, timeout handling, and retry logic.
*   **With Infrastructure Layer:**
    1.  A `Poolboy` pool for DB connections is defined (e.g., `:event_store_db_pool`) and started by the application supervisor (child spec potentially generated via `ConnectionManager.start_pool/3`).
    2.  A `Fuse` instance for DB operations is defined (e.g., `:event_store_db_fuse`) and started (child spec via `CircuitBreakerWrapper.start_fuse_instance/2`).
    3.  The `EventStore`'s database write operation would be wrapped using `ElixirScope.Foundation.Infrastructure.execute_protected/2`:
        ```elixir
        # Inside ElixirScope.Foundation.Services.EventStore
        defp persist_event_to_db(event_struct, state) do
          protection_opts = %{
            circuit_breaker: :event_store_db_fuse,
            connection_pool: %{
              pool_name: :event_store_db_pool,
              transaction_timeout: 5000 # ms
            }
            # Optionally, rate_limit: {:event_store_writes, :db_backend}
          }

          db_write_fun = fn db_worker_pid ->
            # Use db_worker_pid to interact with the database
            case MyApp.DBAdapter.insert_event(db_worker_pid, event_struct) do
              {:ok, id} -> {:ok, id}
              {:error, reason} -> {:error, Error.new(:db_write_failed, "DB write failed: #{inspect(reason)}", %{original: reason})}
            end
          end

          case ElixirScope.Foundation.Infrastructure.execute_protected(protection_opts, db_write_fun) do
            {:ok, event_id_from_db} ->
              # ... success logic
              {:reply, {:ok, event_struct.event_id}, state} # Assuming event_struct.event_id is the canonical one
            {:error, %Error{}=infra_error} ->
              Logger.error("Failed to persist event to DB via infrastructure protection: #{inspect(infra_error)}")
              # ... failure/fallback logic
              {:reply, {:error, infra_error}, state}
          end
        end
        ```

This illustrates that the core logic of `EventStore` now delegates resilience and resource management concerns to the `Infrastructure` facade.

---

### 3. Role of Registries (`ProcessRegistry`, `ServiceRegistry`)

The existing `ProcessRegistry` and `ServiceRegistry` continue to function as before for naming and discovering core ElixirScope services. Their interaction with the new infrastructure components is as follows:

#### 3.1. `ElixirScope.Foundation.ProcessRegistry`
*   This remains the low-level OTP `Registry` wrapper.
*   It is primarily used by `ServiceRegistry`.
*   The new infrastructure *wrappers* (`CircuitBreakerWrapper`, `RateLimiter`, `ConnectionManager`) are modules with functions, not GenServers, so they are not registered here.
*   The GenServers managed by these wrappers (i.e., specific `Fuse` instances or `Poolboy` workers) are named using their respective library's mechanisms (e.g., atom names passed to `Fuse.child_spec` or `Poolboy.child_spec`). `ProcessRegistry` is generally not directly involved in their lookup by client code using the wrappers.

#### 3.2. `ElixirScope.Foundation.ServiceRegistry`
*   Continues to register and provide lookup for main ElixirScope services (e.g., `ConfigServer`, `EventStore`, `TelemetryService`).
*   **Crucially, the *future custom infrastructure GenServers* (`PerformanceMonitor`, `MemoryManager`, `HealthAggregator`) outlined in Section 4.5 of `10_gemini_plan.md` WILL be registered using `ServiceRegistry`**.
    *   Example: `ElixirScope.Foundation.Infrastructure.PerformanceMonitor` would have a `start_link` function using `ServiceRegistry.via_tuple(:production, :performance_monitor)` and other services would use `ServiceRegistry.lookup(:production, :performance_monitor)` to find it.

#### 3.3. Infrastructure Component Naming & Registration
*   **Fuse Instances:** Named using atoms (e.g., `:my_api_fuse`). These names are passed to `CircuitBreakerWrapper.execute/3`. The `Fuse` GenServers are supervised by the application. Dynamic registration of fuse names in `ServiceRegistry` is possible but usually not needed, as the service using the fuse knows its name.
*   **Hammer Rules:** Hammer itself is configured globally or per application. The `RateLimiter` wrapper uses `rule_name_atom` to fetch rule configurations (e.g., from `ConfigServer`). `ServiceRegistry` is not directly involved in Hammer's operation. `Hammer.Supervisor` is added to the app's supervision tree.
*   **Poolboy Pools:** Named using atoms (e.g., `:db_pool`). These names are passed to `ConnectionManager.transaction/3`. The `Poolboy` supervisors are added to the app's supervision tree.
*   **Custom Infra GenServers (Future):** These (e.g., `PerformanceMonitor`) will be standard GenServers, registered and discoverable via `ServiceRegistry` using names like `:performance_monitor`.

---

### 4. Updated Foundation Layer API Contract

The introduction of the infrastructure sub-layer primarily adds new internal capabilities and new modules within `ElixirScope.Foundation.Infrastructure.*`. The existing high-level public APIs of the Foundation Layer (used by Layer 2/AST and above) remain largely unchanged in their signatures, but their implementations will become more resilient.

#### 4.1. Existing Public Facades (Unchanged for External Consumers)

The primary entry points for higher layers remain consistent:
*   **`ElixirScope.Foundation` (`foundation.ex`)**:
    *   `initialize/1`, `status/0`, `available?/0`, `version/0`, `shutdown/0`, `health/0`. *No change to API signatures.* Implementations might internally use infrastructure components for their own health checks or resilience.
*   **`ElixirScope.Foundation.Config` (`config.ex`)**:
    *   `initialize/1`, `status/0`, `get/0`, `get/1`, `update/2`, `validate/1`, `updatable_paths/0`, `reset/0`, `available?/0`, `subscribe/0`, `unsubscribe/0`, `get_with_default/2`, `safe_update/2`. *No change to API signatures.* Internal implementation of `ConfigServer` will use infrastructure components (e.g., rate limiting updates, circuit breaking calls to a persistent backend).
*   **`ElixirScope.Foundation.Events` (`events.ex`)**:
    *   `initialize/0`, `status/0`, `available?/0`, `new_event/2`, `serialize/1`, `deserialize/1`, `store/1`, `store_batch/1`, `get/1`, `query/1`, etc. *No change to API signatures.* Internal implementation of `EventStore` will heavily use infrastructure components (e.g., connection pooling and circuit breakers for persistence, rate limiting for high-volume storage).
*   **`ElixirScope.Foundation.Telemetry` (`telemetry.ex`)**:
    *   `initialize/0`, `status/0`, `execute/3`, `measure/3`, `emit_counter/2`, `emit_gauge/3`, `get_metrics/0`, etc. *No change to API signatures.* Internal implementation of `TelemetryService` might use infrastructure components if it interacts with external metric backends.
*   **`ElixirScope.Foundation.Error` (`error.ex`) and `ElixirScope.Foundation.Types.*`**:
    *   These define data structures and error handling utilities. The infrastructure components will *produce* and *consume* these types, particularly `ElixirScope.Foundation.Types.Error`. New error types related to infrastructure failures (e.g., `:circuit_breaker_open`, `:rate_limited`, `:pool_checkout_timeout`) will be defined or handled by `Error.new/3`.

#### 4.2. New Infrastructure Facade & Wrappers API

These are new modules within the Foundation Layer, primarily intended for use *by other Foundation services* or by application developers who need direct access to these patterns.

**Module: `ElixirScope.Foundation.Infrastructure` (`infrastructure.ex`)**
```elixir
@moduledoc """
Unified facade for applying common infrastructure protections and managing infrastructure components.
"""

@type protection_option ::
  {:circuit_breaker, fuse_name :: atom()} |
  {:circuit_breaker, fuse_name :: atom(), execute_timeout_ms :: pos_integer() | :default} |
  {:rate_limit, {rule_name :: atom(), key_identifier :: term()}} |
  {:rate_limit, {rule_name :: atom(), key_identifier :: term(), increment_by :: pos_integer()}} |
  {:connection_pool, pool_name :: atom()} |
  {:connection_pool, %{pool_name: pool_name :: atom(), transaction_timeout_ms: pos_integer()}}
  # Future: | {:memory_check, threshold_level :: atom()}

@type protection_opts_map :: %{
  optional(:circuit_breaker) => atom() | {atom(), pos_integer() | :default},
  optional(:rate_limit) => {atom(), term()} | {atom(), term(), pos_integer()},
  optional(:connection_pool) => atom() | %{pool_name: atom(), transaction_timeout_ms: pos_integer()}
}

@doc """
Executes the given `operation_fun` with the specified infrastructure protections applied.
Protections are applied in a sensible order (e.g., Rate Limit -> Circuit Breaker -> Pool Transaction).
"""
@spec execute_protected(protection_opts_map(), operation_fun :: (() -> {:ok, term()} | {:error, term()} | term())) ::
  {:ok, term()} | {:error, ElixirScope.Foundation.Types.Error.t()}

@doc """
Initializes and configures core infrastructure components like Hammer.
Ensures supervisors for Fuse, Poolboy, Hammer are running.
(Role might evolve based on dynamic vs. static infra component setup).
"""
@spec initialize_all_infra_components(namespace :: atom(), full_infra_config :: keyword()) ::
  :ok | {:error, ElixirScope.Foundation.Types.Error.t()}
```

**Module: `ElixirScope.Foundation.Infrastructure.CircuitBreakerWrapper`**
```elixir
@moduledoc "Wrapper for :fuse library, providing standardized circuit breaking."

@type fuse_name :: atom()
@type fuse_config_opt :: {atom(), term()} # Options for :fuse.child_spec/2

@doc "Generates a child_spec for supervising a Fuse instance."
@spec start_fuse_instance(fuse_name :: fuse_name(), fuse_config_opts :: [fuse_config_opt()]) :: Supervisor.child_spec()

@doc "Executes `operation_fun` via the named fuse."
@spec execute(fuse_name :: fuse_name(), operation_fun :: (() -> any()), call_timeout_ms :: pos_integer() | :default) ::
  {:ok, term()} | {:error, ElixirScope.Foundation.Types.Error.t()} # Error can be :circuit_breaker_open, :operation_timeout, etc.

@doc "Gets the status of the named fuse."
@spec get_status(fuse_name :: fuse_name()) ::
  {:ok, map()} | {:error, ElixirScope.Foundation.Types.Error.t()} # map is :fuse.status/1 result
```

**Module: `ElixirScope.Foundation.Infrastructure.RateLimiter`**
```elixir
@moduledoc "Wrapper for Hammer library, providing standardized rate limiting."

@type key_identifier :: term() # E.g., {:user_id, 123, :action} or "ip_address"
@type rule_name :: atom() # E.g., :api_calls_per_minute, references a rule in ConfigServer

@doc "Checks if an operation should be allowed based on the rule. Returns :ok or {:error, :rate_limited}."
@spec check_rate(key_identifier :: key_identifier(), rule_name :: rule_name(), increment_by :: pos_integer()) ::
  :ok | {:error, ElixirScope.Foundation.Types.Error.t()} # Error has :rate_limited type and context includes :retry_after_ms

@doc "Gets the current rate limit status for a key-rule combination."
@spec get_status(key_identifier :: key_identifier(), rule_name :: rule_name()) ::
  {:ok, map()} | {:error, ElixirScope.Foundation.Types.Error.t()} # map is Hammer.get_key_status/2 result
```

**Module: `ElixirScope.Foundation.Infrastructure.ConnectionManager`**
```elixir
@moduledoc "Wrapper for Poolboy library, providing standardized connection pooling."

@type pool_name :: atom()
@type poolboy_config_keyword :: [{atom(), term()}] # Poolboy options for :poolboy.child_spec/3
@type poolboy_worker_args :: list() # Args for worker module's init/1

@doc "Generates a child_spec for supervising a Poolboy pool."
@spec start_pool(pool_name :: pool_name(), poolboy_config :: poolboy_config_keyword(), worker_args :: poolboy_worker_args()) :: Supervisor.child_spec()

@doc "Executes `operation_fun` with a worker from the named pool."
@spec transaction(pool_name :: pool_name(), operation_fun_taking_worker_pid :: (pid() -> any()), transaction_timeout_ms :: pos_integer()) ::
  {:ok, term()} | {:error, ElixirScope.Foundation.Types.Error.t()} # Error can be :pool_checkout_timeout, :pool_full, or from operation_fun

@doc "Gets the status of the named Poolboy pool."
@spec get_pool_status(pool_name :: pool_name()) ::
  {:ok, map()} | {:error, ElixirScope.Foundation.Types.Error.t()} # map is :poolboy.status/1 result
```

#### 4.3. Future Custom Infrastructure Services API (Preview)

These services will be GenServers, registered with `ServiceRegistry`. Their APIs would be invoked via GenServer calls.

**Module: `ElixirScope.Foundation.Infrastructure.PerformanceMonitor` (GenServer)**
```elixir
@moduledoc "Service for collecting, aggregating, and analyzing performance metrics."
# Likely to be called via TelemetryService or direct GenServer calls from infra wrappers.

@spec record_metric(service_name :: atom(), operation_name :: atom(), duration_us :: non_neg_integer(), result :: :ok | :error) :: :ok
@spec get_service_performance(service_name :: atom(), operation_name :: atom() | :all) :: {:ok, map()} | {:error, :not_found}
@spec set_alert_threshold(service_name :: atom(), operation_name :: atom(), metric :: :latency_p99 | :error_rate, threshold :: number()) :: :ok
```

**Module: `ElixirScope.Foundation.Infrastructure.MemoryManager` (GenServer)**
```elixir
@moduledoc "Service for monitoring memory and triggering cleanup strategies."

@spec get_memory_pressure_level() :: {:ok, :low | :medium | :high | :critical}
@spec request_cleanup(level :: :aggressive | :normal) :: {:ok, freed_bytes :: non_neg_integer()}
@spec register_cleanup_strategy(strategy_module :: module(), priority :: pos_integer()) :: :ok
```

**Module: `ElixirScope.Foundation.Infrastructure.HealthAggregator` (GenServer)**
```elixir
@moduledoc "Service for aggregating health status from various components."

@spec get_system_health() :: {:ok, %{overall_status: :healthy | :degraded | :critical, components: map()}}
@spec register_health_check_source(source_name :: atom(), check_fun :: (() -> {:ok, map()} | {:error, term()}), interval_ms :: pos_integer()) :: :ok
```

---

### 5. Supervision Strategy for Infrastructure Components

*   **External Library Supervisors:**
    *   `Hammer.Supervisor` will be added to `ElixirScope.Application`'s children list (or a dedicated `ElixirScope.Foundation.InfrastructureSupervisor`).
    *   Each `Fuse` instance (GenServer) needs its child spec (generated by `CircuitBreakerWrapper.start_fuse_instance/2`) added to a supervisor.
    *   Each `Poolboy` pool (itself a supervisor) needs its child spec (generated by `ConnectionManager.start_pool/3`) added to a supervisor.
*   **Custom Infrastructure GenServers (Future):**
    *   `PerformanceMonitor`, `MemoryManager`, `HealthAggregator` will each have their own `start_link` and will be supervised, likely under an `ElixirScope.Foundation.InfrastructureSupervisor`.
*   **`ElixirScope.Foundation.InfrastructureSupervisor` (Recommended):**
    *   A new supervisor, `lib/elixir_scope/foundation/infrastructure_supervisor.ex`.
    *   Strategy: `:one_for_one`.
    *   Children:
        *   `Hammer.Supervisor`
        *   Dynamic supervisors or direct child specs for `Fuse` instances.
        *   `Poolboy` pool supervisors.
        *   Future custom GenServers (`PerformanceMonitor`, etc.).
    *   This supervisor would itself be a child of `ElixirScope.Application`.

---

### 6. Configuration and Observability

*   **Configuration:**
    *   As per `10_gemini_plan.md` (Section 5), configurations for Fuse instances (thresholds, timeouts), Hammer rules (limits, windows), and Poolboy pools (size, worker module) will be managed by `ElixirScope.Foundation.ConfigServer`.
    *   The wrapper modules or the `Infrastructure.initialize_all_infra_components/2` function will fetch these configurations to start and dynamically reconfigure components where possible.
*   **Telemetry:**
    *   As per `10_gemini_plan.md` (Section 6), all infrastructure wrappers and future custom services will emit standardized telemetry events (e.g., `[:elixir_scope, :foundation, :infra, :circuit_breaker, :state_change]`).
    *   `ElixirScope.Foundation.Services.TelemetryService` will be used to consume these events for logging, metrics dashboards (e.g., via Prometheus exporter), and potential alerting.

This refined contract establishes the Infrastructure components as an integral part of the Foundation Layer, enhancing its resilience and capabilities without altering the primary public interfaces consumed by higher layers. The main change is *how* Layer 1 services are implemented internally and the new set of infrastructure tools available *within* Layer 1.