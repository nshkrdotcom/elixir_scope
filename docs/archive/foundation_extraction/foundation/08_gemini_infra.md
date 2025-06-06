Okay, I will now unpack the "ElixirScope Foundation: Infrastructure Layer Design Document" and synthesize it with the previous comprehensive roadmap. This will involve detailing *Phase 1: Core Infrastructure & Resilience Hardening* from the previous roadmap, focusing specifically on **Initiative 1.1: Implement Core Infrastructure Protection Patterns**.

The other parts of Phase 1 (Initiative 1.2 for Service Resilience and Initiative 1.3 for Basic EventStore Persistence) remain as previously detailed, as the Infrastructure Layer plan primarily impacts Initiative 1.1.

---

## ElixirScope Foundation: Synthesized Technical Roadmap (Detailed Phase 1 - Initiative 1.1)

**Version:** 1.1 (Refined for Infrastructure Layer Implementation)
**Date:** May 2025
**Status:** Strategic Execution Plan

**Preamble:** This refined roadmap details the implementation of the Core Infrastructure Protection Patterns, integrating the "ElixirScope Foundation: Infrastructure Layer Design Document" into Phase 1 of the overall ESF evolution.

---

### Phase 1: Core Infrastructure & Resilience Hardening (0-4 Months)

**Goal:** Establish essential infrastructure protections by implementing wrappers around proven external libraries for circuit breaking, rate limiting, and connection pooling. This directly addresses gaps in immediate operational robustness and provides standardized mechanisms for building resilient services.

**Key Initiatives:**

1.  **Initiative 1.1: Implement Core Infrastructure Protection Patterns**
    *   **Context:** This initiative is the direct implementation of the "ElixirScope Foundation: Infrastructure Layer Design Document" (Sections 4.1, 4.2, 4.3, 4.4-initial), `10_gemini_plan.md`. It addresses a critical gap in service resilience and resource management.
    *   **Objective:** Create standardized, configurable, and observable wrappers for `Fuse` (circuit breaking), `Hammer` (rate limiting), and `Poolboy` (connection pooling), along with an initial unified facade.
    *   **Specific Tasks & Deliverables:**

        1.  **Project Setup & Dependencies:**
            *   **Code Impact (Modify):** `mix.exs`
            *   **Key Functionality:** Add necessary dependencies.
                ```elixir
                # mix.exs
                defp deps do
                  [
                    # ... existing deps
                    {:fuse, "~> 2.6"},
                    {:hammer, "~> 6.2"}, # Check latest stable version
                    {:poolboy, "~> 1.5"}  # Check latest stable version
                    # ...
                  ]
                end
                ```
            *   **Rationale/Justification:** Required external libraries for the core protection patterns.

        2.  **Circuit Breaker Framework (Fuse Wrapper):**
            *   **Code Impact (New):**
                *   `lib/elixir_scope/foundation/infrastructure/circuit_breaker_wrapper.ex`
                *   Update `lib/elixir_scope/application.ex` (or a new `lib/elixir_scope/foundation/infrastructure_supervisor.ex`) to supervise `Fuse` instances.
            *   **Key Functionality (`CircuitBreakerWrapper`):**
                *   `start_fuse_instance(fuse_name_atom, fuse_config_opts)`:
                    *   Takes a name (e.g., `:my_service_api_fuse`) and `Fuse` options.
                    *   Returns a child spec suitable for `Supervisor.start_child/2` or inclusion in a children list.
                    *   Example usage: `child_spec = CircuitBreakerWrapper.start_fuse_instance(:external_api_fuse, strategy: {:refusal_strategy, :return, {:error, :circuit_open}}, reset_timeout: 30_000, mf_limit: {5, 10_000})`.
                *   `execute(fuse_name_atom, operation_fun, call_timeout_ms \\ :fuse.config(:default_call_timeout))`:
                    *   Uses `:fuse.ask(fuse_name_atom, :run, operation_fun, call_timeout_ms)`.
                    *   Handles `Fuse`'s return values (`:ok`, `{:ok, val}`, `{:error, :blown_fuse}`, `{:error, :call_timeout}`, etc.).
                *   `get_status(fuse_name_atom)`: Calls `:fuse.status(fuse_name_atom)`.
            *   **Error Handling:**
                *   Translate `:blown_fuse` to `Error.new(:circuit_breaker_open, "Circuit breaker is open for #{fuse_name_atom}", %{fuse: fuse_name_atom}, ...)`
                *   Translate `:call_timeout` (from Fuse) to `Error.new(:operation_timeout, "Operation via fuse #{fuse_name_atom} timed out", %{fuse: fuse_name_atom, timeout: call_timeout_ms}, ...)`
            *   **Telemetry:**
                *   Inside `execute/3`, after `:fuse.ask/3`, emit:
                    *   `[:elixir_scope, :foundation, :infra, :circuit_breaker, :call_executed]` with `%{fuse_name: fuse_name_atom, result: :ok}`.
                    *   `[:elixir_scope, :foundation, :infra, :circuit_breaker, :call_rejected]` with `%{fuse_name: fuse_name_atom, reason: :blown_fuse | :call_timeout}`.
                *   `Fuse` itself emits state change events. `TelemetryService` can be configured to listen to `[:fuse, :state_change]` and re-emit them under ElixirScope's namespace or process them.
                    *   Alternative: `CircuitBreakerWrapper` could use `:fuse.subscribe(fuse_name)` to get state changes and emit ElixirScope-namespaced telemetry.
            *   **Configuration:** `fuse_config_opts` passed to `start_fuse_instance/2` will often come from `ConfigServer` or application config.
            *   **Rationale/Justification:** Provides a standardized, observable layer over `Fuse`, abstracting its direct API.
            *   **Testing Focus:**
                *   Unit: Correct child spec generation, `:fuse.ask` calls, error translation, telemetry emission.
                *   Integration: Starting a `Fuse` instance, tripping the breaker, half-open state, reset.

        3.  **Rate Limiting Framework (Hammer Wrapper):**
            *   **Code Impact (New):**
                *   `lib/elixir_scope/foundation/infrastructure/rate_limiter.ex`
                *   Update `lib/elixir_scope/application.ex` to include `Hammer.Supervisor`.
            *   **Key Functionality (`RateLimiter`):**
                *   `check_rate(key_identifier_term, rule_name_atom, increment_by \\ 1)`:
                    *   `key_identifier_term`: e.g., `{:user_id, 123, :api_call}` or a simple string/atom.
                    *   `rule_name_atom`: e.g., `:api_calls_per_minute`.
                    *   Internal `build_hammer_key/1` to convert `key_identifier_term` to a unique string for Hammer.
                    *   Fetch rule details (e.g., `{scale_ms, limit_num}`) from `ConfigServer` based on `rule_name_atom`.
                    *   Calls `Hammer.check_rate_inc(build_hammer_key(...), scale_ms, limit_num, increment_by)`.
                *   `get_status(key_identifier_term, rule_name_atom)`: Calls `Hammer.get_key_status(...)`.
            *   **Error Handling:**
                *   Translate `{:error, {:rate_limited, _ttl_ms}}` from Hammer into `Error.new(:rate_limited, "Rate limit exceeded for #{inspect(key_identifier_term)} on rule #{rule_name_atom}", %{key: key_identifier_term, rule: rule_name_atom, retry_after_ms: _ttl_ms}, ...)`.
            *   **Telemetry:**
                *   `[:elixir_scope, :foundation, :infra, :rate_limiter, :request_allowed]` with `%{key: key_identifier_term, rule: rule_name_atom}`.
                *   `[:elixir_scope, :foundation, :infra, :rate_limiter, :request_denied]` with `%{key: key_identifier_term, rule: rule_name_atom}`.
            *   **Configuration:**
                *   `config :hammer, backend: Hammer.Backend.ETS` (or Redis for distributed).
                *   Rate limit rules (scale, limit) managed by `ConfigServer`, identified by `rule_name_atom`.
            *   **Rationale/Justification:** Standardizes rate limiting, decouples services from Hammer's direct API, enables centralized rule management.
            *   **Testing Focus:**
                *   Unit: Key construction, rule fetching, Hammer function calls, error translation, telemetry.
                *   Integration: Hitting rate limits, expiration of limits.

        4.  **Connection Pooling Framework (Poolboy Wrapper):**
            *   **Code Impact (New):**
                *   `lib/elixir_scope/foundation/infrastructure/connection_manager.ex`
                *   `lib/elixir_scope/foundation/infrastructure/pool_workers/` (directory)
                *   `lib/elixir_scope/foundation/infrastructure/pool_workers/dummy_worker.ex` (example worker for testing)
                *   Update `lib/elixir_scope/application.ex` (or infra supervisor) for `Poolboy` pool supervision.
            *   **Key Functionality (`ConnectionManager`):**
                *   `start_pool(pool_name_atom, poolboy_config_keyword_list, poolboy_worker_args \\ [])`:
                    *   Returns a child spec for `Poolboy`. `pool_name_atom` will be used in `poolboy_config_keyword_list` like `name: {:local, pool_name_atom}`.
                    *   Example: `child_spec = ConnectionManager.start_pool(:db_workers, [size: 5, worker_module: DBWorker], [db_config: "..."])`.
                *   `transaction(pool_name_atom, operation_fun_taking_worker_pid, transaction_timeout_ms \\ 5000)`:
                    *   Calls `:poolboy.transaction(pool_name_atom, operation_fun_taking_worker_pid, transaction_timeout_ms)`.
                *   `get_pool_status(pool_name_atom)`: Calls `:poolboy.status(pool_name_atom)`.
            *   **Worker Modules (`PoolWorkers.DummyWorker`):**
                *   Implements `GenServer` with `start_link/1` (to be called by Poolboy) and `init/1`.
                *   Example operation: `handle_call(:ping, _from, state) -> {:reply, :pong, state}`.
            *   **Error Handling:**
                *   Translate `:poolboy.transaction` errors (`:timeout`, `{:error, :checkout_timeout}`, `{:error, :full}`) to structured `Types.Error`.
                *   e.g., `Error.new(:pool_checkout_timeout, "Timeout checking out worker from pool #{pool_name_atom}", %{pool: pool_name_atom, timeout: transaction_timeout_ms}, ...)`.
            *   **Telemetry:**
                *   `[:elixir_scope, :foundation, :infra, :connection_pool, :transaction_executed]` with `%{pool_name: pool_name_atom, duration_ms: ..., result: :ok | :error}`.
                *   `[:elixir_scope, :foundation, :infra, :connection_pool, :checkout_timeout]` with `%{pool_name: pool_name_atom}`.
                *   `[:elixir_scope, :foundation, :infra, :connection_pool, :pool_full]` with `%{pool_name: pool_name_atom}`.
            *   **Configuration:** `poolboy_config_keyword_list` and `poolboy_worker_args` provided per pool, often from `ConfigServer` or app config.
            *   **Rationale/Justification:** Standardizes pool usage, abstracts Poolboy, provides observability.
            *   **Testing Focus:**
                *   Unit: Child spec generation, `:poolboy.transaction` calls, error translation, telemetry.
                *   Integration: Starting pools, successful transactions, checkout timeouts, pool full scenarios.

        5.  **Unified Infrastructure Facade (Initial Implementation):**
            *   **Code Impact (New):** `lib/elixir_scope/foundation/infrastructure/infrastructure.ex`
            *   **Key Functionality:**
                *   `initialize_all_infra_components(namespace \\ :production, full_infra_config)`:
                    *   (Simplified for Phase 1) Ensures Hammer supervisor is running. Does not dynamically start Fuses/Pools yet, as those are in app supervision tree.
                    *   Future: Could take declarative config for fuses/pools and dynamically start/supervise them if not managed by app's top-level supervisor.
                *   `execute_protected(protection_opts_map, operation_fun)`:
                    *   `protection_opts_map`: e.g., `%{circuit_breaker: :my_fuse}` OR `%{rate_limit: {:my_rule, key_term}}` OR `%{connection_pool: :my_pool}`.
                    *   For Phase 1, this function will handle *only one* protection type per call. It will look at the keys in `protection_opts_map` and dispatch to the appropriate wrapper.
                    *   Example:
                        ```elixir
                        def execute_protected(%{circuit_breaker: fuse_name} = opts, fun) do
                          timeout = Map.get(opts, :timeout) # Optional timeout for the CB execute
                          CircuitBreakerWrapper.execute(fuse_name, fun, timeout || :default_timeout)
                        end
                        def execute_protected(%{rate_limit: {rule_name, key_term}} = _opts, fun) do
                          case RateLimiter.check_rate(key_term, rule_name) do
                            :ok -> {:ok, fun.()}
                            {:error, _reason} = err -> err
                          end
                        end
                        # ... and so on for connection_pool
                        ```
            *   **Rationale/Justification:** Provides a single entry point for basic protections. Sets up for more complex orchestration later.
            *   **Testing Focus:** Unit tests for dispatching to the correct wrapper based on `protection_opts_map`.

        6.  **Documentation & Supervision:**
            *   **Code Impact (Modify/New):**
                *   Moduledocs for all new `infrastructure/` modules.
                *   Update `DEV.md` to reflect the new `lib/elixir_scope/foundation/infrastructure/` directory and its components.
                *   Update `docs/foundation/04_C4_CMM_SIMON_BROWN_GREGOR_HOHPE.md` (or a new C4 diagram for Infrastructure Layer) to show these components.
                *   Consider creating `lib/elixir_scope/foundation/infrastructure_supervisor.ex` to group supervision of dynamic Fuses, Pools (if not directly in `Application.ex`), and future custom infra GenServers. For Phase 1, placing `Hammer.Supervisor` and static `Fuse`/`Poolboy` child specs in `Application.ex` is acceptable.
            *   **Rationale/Justification:** Essential for usability and maintainability.

**Success Metrics for Initiative 1.1 (and thus a key part of Phase 1 Success):**
*   `CircuitBreakerWrapper`, `RateLimiter`, and `ConnectionManager` are implemented, unit-tested, and provide observable behavior via telemetry.
*   `Infrastructure.execute_protected/2` can successfully apply individual protection patterns.
*   Services (hypothetically, or in test harnesses) can use these wrappers to protect operations.
*   Supervision for `Fuse`, `Hammer`, and `Poolboy` is correctly set up in the application.
*   Documentation for the new infrastructure components is complete.

---

**(Initiative 1.2: Enhance Service Startup & Inter-Service Resilience - Remains as per previous detailed roadmap)**
**(Initiative 1.3: Basic EventStore Persistence - Remains as per previous detailed roadmap)**

This level of detail for Initiative 1.1 should provide a clear path for implementation, connecting directly to the Infrastructure Layer Design Document and ensuring that the foundational protection patterns are in place early. Subsequent phases will build upon this.