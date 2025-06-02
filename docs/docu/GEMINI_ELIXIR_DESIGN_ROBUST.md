Okay, this is a great goal. Let's synthesize the best practices discussed into a comprehensive technical document that can serve as a standard for design and implementation within your ElixirScope project, especially for its foundational layers and beyond.

---

**ElixirScope: Robust Elixir Design & Implementation Standard**

**Version:** 1.0
**Date:** October 26, 2023
**Audience:** All ElixirScope Developers

**1. Introduction**

This document outlines the standard design and implementation patterns to be followed within the ElixirScope project. The goal is to build a robust, maintainable, testable, and scalable system by leveraging Elixir's canonical patterns and OTP principles effectively. Adherence to these standards will ensure consistency across the codebase, reduce cognitive overhead, and facilitate easier collaboration and onboarding.

**2. Guiding Principles**

*   **Explicitness over Implicitness:** Make contracts, data flow, and error handling clear and visible.
*   **Consistency:** Apply patterns uniformly across the system.
*   **Separation of Concerns:** Modules should have a single, well-defined responsibility.
*   **Testability:** Design for testability from the outset. Pure functions and clear contracts are key.
*   **Composability:** Functions and modules should be easy to combine to build larger features.
*   **Predictability:** Developers should be able to easily reason about the behavior of a function or module, especially regarding success and failure.

**3. Core Architectural Patterns**

**3.1. Consistent Return Value Contracts (The "Ok/Error Tuple" Rule)**

This is the most fundamental rule for functions that can succeed or fail.

*   **Rule 1: Operations that can fail AND return data on success:**
    *   **Signature:** `(...args :: any()) :: {:ok, result_type} | {:error, Error.t()}`
    *   **Example:**
        ```elixir
        @spec get_user(id :: integer()) :: {:ok, User.t()} | {:error, Error.t()}
        def get_user(id) do
          case Repo.get(User, id) do
            nil  -> {:error, Error.new(:data_not_found, "User not found", context: %{id: id})}
            user -> {:ok, user}
          end
        end
        ```

*   **Rule 2: Operations that can fail AND perform a side-effect without meaningful return data on success:**
    *   **Signature:** `(...args :: any()) :: :ok | {:error, Error.t()}`
    *   **Example:**
        ```elixir
        @spec update_user_status(user_id :: integer(), status :: atom()) :: :ok | {:error, Error.t()}
        def update_user_status(user_id, status) do
          # Imagine this updates a database or an external service
          case UserRepo.set_status(user_id, status) do
            :ok -> :ok
            {:error, reason} -> {:error, Error.new(:external_service_error, "Failed to update status", context: %{reason: reason})}
          end
        end
        ```

*   **Rule 3: Operations that cannot practicably fail:**
    *   **Signature:** `(...args :: any()) :: result_type`
    *   **Example:**
        ```elixir
        @spec format_username(first_name :: String.t(), last_name :: String.t()) :: String.t()
        def format_username(first_name, last_name) do
          "#{first_name}.#{last_name}" # Assumes inputs are valid strings
        end
        ```

*   **Rationale:**
    *   **Predictability:** Callers always know how to handle the outcome using `case`, `with`, or pattern matching.
    *   **Composability:** Enables clean chaining of operations using `with`.
    *   **Explicit Error Handling:** Errors are values, not just exceptions.

*   **Anti-Patterns to Avoid:**
    *   Mixing `:ok` with `{:ok, value}` for similar types of operations.
    *   Returning `nil` or `false` to indicate failure.
    *   Returning `{:error, :some_atom_reason}` instead of `{:error, Error.t()}`.
    *   Raising exceptions for expected failure scenarios (e.g., "not found").

**3.2. Behaviours for Defining Contracts**

Behaviours are used to define explicit public APIs or contracts for a set of related functionalities that can have multiple implementations.

*   **Definition:**
    ```elixir
    # lib/elixir_scope/foundation/contracts/configurable.ex
    defmodule ElixirScope.Foundation.Contracts.Configurable do
      @moduledoc "Defines the contract for configuration providers."

      alias ElixirScope.Foundation.Types.Config
      alias ElixirScope.Foundation.Types.Error

      @callback get() :: {:ok, Config.t()} | {:error, Error.t()}
      @callback get(path :: [atom()]) :: {:ok, term()} | {:error, Error.t()}
      @callback update(path :: [atom()], value :: term()) :: :ok | {:error, Error.t()} # Or {:ok, Config.t()} if it returns the updated config
      @callback validate(config :: Config.t()) :: :ok | {:error, Error.t()} # Or {:ok, Config.t()} if it transforms
    end
    ```

*   **Implementation:**
    ```elixir
    defmodule ElixirScope.Foundation.Services.ConfigServer do
      @behaviour ElixirScope.Foundation.Contracts.Configurable
      # ... GenServer implementation ...
      @impl ElixirScope.Foundation.Contracts.Configurable
      def get() do
        # ...
      end
      # ... other callbacks ...
    end
    ```

*   **Rationale:**
    *   **Clarity:** Explicitly defines what a component promises to do.
    *   **Polymorphism:** Allows swapping implementations (e.g., for different storage backends, or for testing).
    *   **Testability:** Enables mocking with libraries like `Mox`.
    *   **Compiler Warnings:** The compiler will warn if an implementing module doesn't correctly implement all callbacks or if signatures mismatch.

**3.3. Separation of Concerns & Layered Architecture**

Modules and layers should have distinct responsibilities.

*   **Module-Level Separation:**
    *   **Types (e.g., `ElixirScope.Foundation.Types.Config`):** Pure data structures (structs) with `@typedoc`. No logic.
    *   **Logic/Validation (e.g., `ElixirScope.Foundation.Validation.ConfigValidator`):** Pure functions. stateless, easily testable. Take data in, return data (or `{:ok, data} | {:error, reason}`).
    *   **Services/Infrastructure (e.g., `ElixirScope.Foundation.Services.ConfigServer`):** Stateful components (GenServers, ETS tables). Manage state, concurrency, and side-effects. They *delegate* logic to pure function modules.
    *   **Public API Facades (e.g., `ElixirScope.Foundation.Config`):** Thin wrappers that expose the functionality of the component. They orchestrate calls to Logic and Service modules.

*   **System-Level Layering (Example):**
    1.  **Layer 1: Foundation - Core Types, Contracts, and Services:**
        *   Examples: `ElixirScope.Foundation.Types.*`, `ElixirScope.Foundation.Contracts.*`, `ElixirScope.Foundation.Services.*`, `ElixirScope.Foundation.Config`.
        *   Responsibilities: Basic utilities, core data structures, shared service contracts, fundamental GenServer implementations.
        *   Dependencies: Only Elixir/OTP.
    2.  **Layer 2: Core Business Logic:**
        *   Examples: `ElixirScope.Analysis.CodeAnalyzer` (pure logic part), `ElixirScope.AST.Parser`.
        *   Responsibilities: Domain-specific calculations, transformations, validations. Primarily pure functions.
        *   Dependencies: Layer 1.
    3.  **Layer 3: Application Services & Orchestration:**
        *   Examples: GenServers or processes that orchestrate multiple Core Logic components and Foundation services.
        *   Responsibilities: Managing workflows, coordinating complex operations.
        *   Dependencies: Layer 1, Layer 2.
    4.  **Layer 4: API/Adapters/Presentation:**
        *   Examples: Phoenix controllers/channels, Public API modules for external consumption (`ElixirScope` top-level module).
        *   Responsibilities: Handling external requests, formatting responses, interacting with external systems.
        *   Dependencies: Layer 1, Layer 2, Layer 3.

*   **Dependency Rule:** Dependencies must only flow downwards. A lower layer must not know about a higher layer.

*   **Rationale:**
    *   **Reduced Complexity:** Each part is easier to understand.
    *   **Enhanced Testability:** Pure logic layers are easy to unit test. Service layers can be tested for state/concurrency.
    *   **Improved Maintainability:** Changes in one layer are less likely to ripple through unrelated parts of the system.

**3.4. Dependency Injection (DI)**

Provide dependencies to a module/function rather than hardcoding them.

*   **Mechanism:** Primarily through function arguments with default values.
    ```elixir
    defmodule ElixirScope.Analysis.CodeAnalyzer do
      alias ElixirScope.Foundation.Config # Default implementation
      alias ElixirScope.Foundation.Contracts.Configurable

      @spec analyze(code :: binary(), config_provider :: module()) :: {:ok, map()} | {:error, Error.t()}
      def analyze(code, config_provider \\ Config) do
        # Type check the injected module at runtime if necessary,
        # or rely on Dialyzer for compile-time checks if the type is more specific
        # (e.g., config_provider :: Configurable.t() - though module type is tricky)

        with {:ok, config} <- config_provider.get() do
          # ... perform analysis using config ...
          {:ok, %{analysis_result: "..."}}
        end
      end
    end
    ```

*   **When to Use:**
    *   For dependencies that have alternative implementations (e.g., different storage backends, payment gateways).
    *   For dependencies that need to be mocked during testing (especially external services or stateful components).
    *   When a module in a higher layer consumes a service/contract from a lower layer (as shown in the `CodeAnalyzer` example).

*   **When NOT to Use (Generally):**
    *   For core Elixir/OTP modules (`Map`, `Enum`, `GenServer` client API).
    *   For tightly coupled internal modules *within the same logical component or layer* where the dependency is fundamental and unlikely to change (e.g., `ElixirScope.Foundation.Services.ConfigServer` might directly use `ElixirScope.Foundation.Validation.ConfigValidator` without injection if they are considered parts of the same "Config" component). However, if `ConfigValidator` implemented a behaviour and could be swapped, DI would be appropriate.
    *   The `Foundation` layer itself will have minimal internal DI. DI is more prevalent in higher layers consuming `Foundation` services.

*   **Testing with DI & Mox:**
    *   Define a behaviour (e.g., `Configurable`).
    *   Your real module implements it.
    *   In tests, use `Mox.defmock/2` to create a mock for the behaviour.
    *   Inject the mock into the module under test.
    *   `Mox.expect/4` to set expectations on the mock.

**4. Error Handling Standard**

*   **Primary Error Type: `ElixirScope.Foundation.Error.t()`**
    *   All functions adhering to "Rule 1" or "Rule 2" in section 3.1 MUST return `{:error, %ElixirScope.Foundation.Error{}}` on failure.
    *   The `Error.t()` struct should contain:
        *   `code`: A unique numerical/symbolic code for the error.
        *   `error_type`: A descriptive atom for the error category (e.g., `:validation_failed`, `:data_not_found`).
        *   `message`: A human-readable message.
        *   `context`: A map of relevant data at the time of error.
        *   `severity`: (e.g., `:low`, `:medium`, `:high`, `:critical`).
        *   `correlation_id`: To trace the error across services/operations.
        *   `timestamp`: When the error occurred.
        *   (Optionally: `stacktrace`, `category`, `subcategory`, `retry_strategy`).

*   **`ElixirScope.Foundation.ErrorContext.t()`**
    *   Used to track an operation's lifecycle and provide rich debugging information.
    *   Contains `operation_id`, `module`, `function`, `correlation_id`, `breadcrumbs`, `metadata`.
    *   Use `ErrorContext.with_context(context, fn -> ... end)` to wrap operations. This helper should:
        *   Store the context in the process dictionary for emergency recovery.
        *   Automatically capture exceptions and convert them into structured `Error.t()` objects, augmented with the `ErrorContext`.
        *   Clean up the process dictionary entry on successful completion or after an exception.

*   **Error Propagation:**
    *   Errors should generally be propagated upwards by returning the `{:error, Error.t()}` tuple.
    *   Avoid rescuing exceptions broadly. Let `ErrorContext.with_context` handle unexpected exceptions.
    *   If an error is handled and recovered from, the function may return an `{:ok, ...}` or `:ok` result.
    *   When an underlying function call returns an `{:error, Error.t()}`, the calling function should typically:
        1.  Return the error directly: `{:error, error_from_dependency}`.
        2.  Or, wrap the error if additional context is needed:
            ```elixir
            case AnotherModule.do_something() do
              {:ok, result} -> {:ok, result}
              {:error, inner_error} ->
                Error.new(:operation_failed, "Sub-operation failed", context: %{inner: inner_error})
                |> then(&{:error, &1}) # or use Error.error_result/3
            end
            ```

*   **Telemetry for Errors:**
    *   The `Error.collect_error_metrics/1` function (or similar) should be called (often automatically by `with_context`) to emit telemetry events for errors, allowing for monitoring and alerting.

**5. Testing Standard**

A comprehensive testing strategy is vital for robust design.

*   **Unit Tests:**
    *   Focus: Individual pure functions.
    *   Tool: `ExUnit`.
    *   Example: Testing functions in `ElixirScope.Foundation.Validation.ConfigValidator`.
    *   Goal: Verify correctness of logic in isolation.

*   **Contract Tests:**
    *   Focus: Verifying that an implementation module correctly adheres to its `Behaviour` contract.
    *   Tool: `ExUnit` with `Mox` (or by directly calling the implementation).
    *   Example: `ConfigurableContractTest` ensuring `ElixirScope.Foundation.Config` (or `Services.ConfigServer`) correctly implements `ElixirScope.Foundation.Contracts.Configurable`.
        ```elixir
        # Conceptual contract test
        defmodule MyService.ContractTest do
          use ExUnit.Case
          alias ElixirScope.Foundation.Contracts.SomeBehaviour
          alias ElixirScope.MyService.Implementation

          @behaviour_module SomeBehaviour
          @implementation_module Implementation

          test "get/1 contract" do
            # Setup data
            # Call @implementation_module.get(data)
            # Assert the return type matches the @callback spec in @behaviour_module
            # e.g., assert {:ok, _} = result or {:error, %Error{}} = result
          end
        end
        ```

*   **Integration Tests:**
    *   Focus: Interactions between multiple modules, including GenServers and their state.
    *   Tool: `ExUnit`.
    *   Example: `ConfigServerTest` testing the `ConfigServer` GenServer's lifecycle, message handling, and state changes. Also testing the interaction between `ElixirScope.Foundation.Config` (facade) and `ElixirScope.Foundation.Services.ConfigServer`.
    *   Goal: Verify that components work together as expected.

*   **Property-Based Testing:**
    *   Focus: Testing properties of functions over a wide range of generated inputs.
    *   Tool: `StreamData` (or other PBT libraries).
    *   Example: Testing validation logic (`ConfigValidator`) with many valid and invalid config structures. Testing serialization/deserialization round-trips.
    *   Goal: Uncover edge cases and ensure robustness against varied inputs.

*   **Mox Usage:**
    *   Primarily for mocking implementations of your *own Behaviours*, especially when those behaviours represent external dependencies (HTTP clients, databases that are not yet built) or stateful internal services that you want to isolate during a unit/integration test of another component.
    *   **Do not** mock your own core modules directly if they don't implement a behaviour you're testing against. Use DI with real (but perhaps simplified test-specific) implementations or test them directly.

**6. Code Style & Conventions**

*   **Formatting:** Adhere strictly to `mix format`.
*   **Naming:**
    *   Modules: UpperCamelCase (e.g., `ConfigValidator`).
    *   Functions: snake_case (e.g., `validate_config`).
    *   Predicate functions (return boolean): End with `?` (e.g., `valid_config?`).
*   **Typespecs (`@spec`):** Mandatory for all public functions and recommended for private functions where complex types are involved. Aim for Dialyzer to pass cleanly.
*   **Documentation (`@moduledoc`, `@doc`):** Mandatory for all modules and public functions. Explain the "what" and "why," not just the "how." Include examples where appropriate.
*   **Alias Usage:** Use `alias` for frequently used modules. Avoid overly long alias chains.

**7. Module Design Philosophy**

*   **Single Responsibility:** Each module should do one thing well.
*   **Thin Public APIs:** Expose only what is necessary. Internal implementation details should remain private.
*   **Minimize State:** Prefer pure functions. Encapsulate state within GenServers or other processes when necessary.
*   **Clear Boundaries:** Use Behaviours and well-defined public functions to establish clear interaction points between modules/components.

**8. Standard Review & Evolution**

This document is a living standard. It will be reviewed periodically (e.g., quarterly or as major new patterns emerge) and updated by the core architectural team. Feedback and suggestions for improvement are encouraged via [designated channel/process].

---

This document provides a strong foundation. You would then populate the `ElixirScope.Foundation.Error.t()` definition with specific error codes and categories relevant to your domain, and ensure your `ErrorContext` is used consistently.

Remember to actually create the modules mentioned in the proposed architecture (e.g., `ElixirScope.Foundation.Contracts.Configurable`, `Types.Config`, `Validation.ConfigValidator`, `Services.ConfigServer`) and refactor existing code (like your `Config.ex`) to fit this structure.
