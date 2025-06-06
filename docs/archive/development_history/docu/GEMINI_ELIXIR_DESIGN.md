Okay, this is an excellent foundation. Let's synthesize this into a comprehensive technical document that can serve as a standard for robust Elixir system design and implementation, drawing heavily from the principles discussed.

---

## Elixir System Design & Implementation Standard

**Version:** 1.0
**Date:** (Current Date)
**Purpose:** This document outlines the canonical patterns, architectural principles, and best practices for designing and implementing robust, maintainable, and testable Elixir systems within [Your Organization/Project Name]. Adherence to this standard will promote consistency, reduce complexity, and improve overall code quality.

**Target Audience:** All Elixir developers involved in the design, implementation, and review of Elixir-based services and libraries. Familiarity with core BEAM/OTP principles is assumed.

### 1. Core Guiding Principles

1.  **Consistency is Key:** Uniform patterns, especially for return values and error handling, significantly reduce cognitive load and prevent bugs.
2.  **Clarity through Contracts:** Behaviours should be used to define explicit interfaces between components, improving decoupling and testability.
3.  **Separation of Concerns:** Distinguish clearly between pure logic, stateful processes, and external interactions.
4.  **Immutability and Pure Functions:** Leverage Elixir's strengths. Prefer pure functions for business logic and transformations.
5.  **Testability by Design:** Architecture should inherently support various forms of testing (unit, contract, integration, property-based).
6.  **Leverage OTP, Don't Reinvent:** Utilize OTP primitives (GenServer, Supervisor, Application) for concurrency, state management, and fault tolerance, but encapsulate their complexities appropriately.

### 2. Standardized Architecture: Layered Approach

We adopt a three-layered architecture to promote separation of concerns:

#### Layer 1: Core Types & Contracts (The "What")

*   **Purpose:** Defines the data structures and interfaces of the system's foundational elements. This layer contains no executable logic beyond type definitions and specifications.
*   **Components:**
    *   **`YourApp.Foundation.Types.*`**: Pure Elixir structs representing core domain entities (e.g., `Types.Config`, `Types.User`, `Types.Error`). These are passive data containers.
        *   Must include `@typedoc` and `@type` definitions.
        *   May include `defstruct` and basic helper functions for creation if appropriate (e.g., `Error.new/2`).
    *   **`YourApp.Foundation.Contracts.*`**: Behaviours defining the contracts for services (e.g., `Contracts.Configurable`, `Contracts.UserRepository`).
        *   Must use `@callback` to define function signatures and expected return types (using typespecs).
        *   Callbacks must adhere to the Standardized Return Values (Section 3.1).
*   **Dependencies:** May depend on Elixir standard library types. No dependencies on Layer 2 or Layer 3.

#### Layer 2: Core Logic - Pure Functions (The "How," without side-effects)

*   **Purpose:** Implements business logic, validation, and data transformation. Functions in this layer must be pure and stateless.
*   **Components:**
    *   **`YourApp.Foundation.Validation.*`** (e.g., `Validation.ConfigValidator`, `Validation.UserValidator`): Modules containing pure functions for validating data structures from Layer 1.
    *   **`YourApp.Foundation.Logic.*`** (e.g., `Logic.ConfigLogic`, `Logic.UserLogic`): Modules containing pure business logic functions operating on Layer 1 types.
*   **Characteristics:**
    *   Functions take data (usually Layer 1 types) as input and return data or a standard result tuple.
    *   No side effects (no GenServer calls, no database access, no HTTP requests, no file I/O, no global state mutation).
    *   Highly testable with unit tests and property-based tests.
*   **Dependencies:** Depends on Layer 1 (Types). No dependencies on Layer 3.

#### Layer 3: Infrastructure - Processes & Side Effects (The "Execution")

*   **Purpose:** Manages state, concurrency, external interactions (databases, APIs, file system), and OTP processes. Implements the contracts defined in Layer 1.
*   **Components:**
    *   **`YourApp.Foundation.Services.*`** (e.g., `Services.ConfigServer`, `Services.UserRepo.DB`): GenServers, Ecto Repos, HTTP Clients, etc. These are the stateful or side-effectful implementations.
        *   These modules often implement behaviours from `YourApp.Foundation.Contracts.*`.
        *   They *delegate* complex logic to Layer 2 pure functions. For example, a `ConfigServer.handle_call({:update, ...}, ...)` would call a `Validation.ConfigValidator` function and then a `Logic.ConfigLogic` function.
    *   **Public API / Context Modules** (e.g., `YourApp.Foundation.Config`, `YourApp.Users`): These are the primary entry points for other parts of the application or external callers.
        *   They are "thin wrappers" that expose a clean public API.
        *   They implement behaviours from `YourApp.Foundation.Contracts.*`.
        *   They delegate calls to the appropriate `Services.*` module (e.g., a GenServer) or, if the operation is stateless, potentially directly to a `Logic.*` module.
        *   All public functions must adhere to Standardized Return Values (Section 3.1).
*   **Dependencies:** Depends on Layer 1 (Types, Contracts) and Layer 2 (Validation, Logic).

### 3. Key Design Patterns & Practices

#### 3.1. Standardized Return Values (Result Tuples)

*   **Rule 1 (Fallible Operations):** If a function can fail for reasons considered "normal" (e.g., validation error, resource not found, external service unavailable), it **MUST** return:
    *   `{:ok, result_value}` on success.
    *   `{:error, %YourApp.Foundation.Types.Error{}}` on failure (see Section 3.2).
*   **Rule 2 (Side-Effect Operations without Meaningful Return Data):** If a fallible function's primary purpose is a side-effect and it doesn't have a meaningful data value to return on success (e.g., writing a file, emitting a telemetry event, `GenServer.stop`):
    *   It **MUST** return `:ok` on success.
    *   It **MUST** return `{:error, %YourApp.Foundation.Types.Error{}}` on failure.
*   **Rule 3 (Infallible Operations):** If a function cannot practically fail under normal operating conditions (e.g., simple data formatting, accessing a known-good struct field, pure calculations), it **MAY** return the value directly.
    *   Example: `Utils.format_bytes(1024) :: String.t()`
*   **Absolutely No Mixing:**
    *   Do NOT return `:ok` when `{:ok, value}` is expected for a data-returning successful operation.
    *   Do NOT return `value` directly if the operation can fail; use `{:ok, value}`.
    *   Do NOT return `{:error, :some_atom}` or `{:error, "string message"}`; always use the structured Error type.
*   **`with` Statements:** Leverage `with` for elegant chaining of operations that return result tuples.

#### 3.2. Error Handling Strategy

*   **Structured Errors:** All errors returned in `{:error, reason}` tuples (as per Section 3.1) **MUST** use a standardized error struct:
    ```elixir
    defmodule YourApp.Foundation.Types.Error do
      @typedoc """
      Standardized error structure for all operations.
      - `:code` - A unique atom representing the error type (e.g., :validation_error, :not_found, :external_service_failure).
      - `:message` - A human-readable message (primarily for logging/debugging).
      - `:details` - A map containing context-specific information about the error (e.g., validation changesets, failing parameters).
      - `:original_error` - Optional, the original exception or error tuple if this error is a wrapper.
      """
      @type t :: %__MODULE__{
              code: atom(),
              message: String.t() | nil,
              details: map() | nil,
              original_error: term() | nil
            }
      defstruct [:code, :message, :details, :original_error]

      def new(code, message \\ nil, details \\ %{}, original_error \\ nil) do
        %__MODULE__{code: code, message: message, details: details, original_error: original_error}
      end
    end
    ```
*   **Error Codes:** Use consistent, well-defined atoms for `Error.t().code`. Consider a central registry or documentation for these codes.
*   **No Raw Exceptions for Flow Control:** Exceptions should be reserved for truly *exceptional* or unexpected situations (programmer errors, system failures), not for predictable business rule failures (e.g., invalid input).
*   **ErrorContext:** For operations spanning multiple steps, an `ErrorContext` (as potentially already in use) can be valuable for tracking the operation path leading to an error. This should be managed implicitly (e.g., via the process dictionary for a given call chain) or passed explicitly where necessary.

#### 3.3. Behaviours for Contracts

*   All significant service interfaces (e.g., configuration access, data repositories, external service clients) **MUST** be defined by a behaviour in Layer 1 (`YourApp.Foundation.Contracts.*`).
*   Modules in Layer 3 that provide these services **MUST** use `@behaviour YourApp.Foundation.Contracts.MyContract` and `@impl true` for callback implementations.
*   The compiler will enforce that implementations satisfy the contract.
*   Benefits: Decoupling, clear interfaces, mockability for testing.

#### 3.4. Dependency Injection (DI)

*   **Purpose:** To decouple components and improve testability by allowing dependencies to be replaced, typically with mocks or alternative implementations.
*   **Standard Pattern:** Function arguments with defaults.
    ```elixir
    # Example: A service in a higher layer using a Foundation service
    defmodule YourApp.BusinessLogic.OrderProcessor do
      alias YourApp.Foundation.Contracts.ProductFetcher
      alias YourApp.Foundation.Products # Default implementation

      # @product_fetcher module must implement ProductFetcher behaviour
      def process_order(order_id, opts \\ [], product_fetcher \\ Products) do
        with {:ok, product_data} <- product_fetcher.get_product_details(opts[:product_id]) do
          # ... logic
        end
      end
    end
    ```
*   **When to Use DI:**
    *   **Between Architectural Layers:** Higher layers (e.g., Business Logic) depending on lower layers (e.g., Foundation services) should inject the lower-layer dependency.
    *   **External Dependencies:** When interacting with external systems (HTTP clients, databases via Ecto.Repo) whose implementations might vary or need mocking.
    *   **For Testability of Core Utilities:** Within Foundation, DI can be used sparingly for things like:
        *   Telemetry backend (`backend \\ :telemetry`)
        *   Time/ID generation for deterministic tests (`id_generator \\ &SomeGenerator.uuid4/0`)
*   **When NOT to Use DI:**
    *   **Between tightly coupled modules within the *same* logical component or sub-layer of Foundation** (e.g., `ConfigServer` does not need to inject `ConfigValidator` if they are both part of the "Config" foundation feature). They can directly call each other.
    *   **For Core Elixir/OTP functions** (e.g., `GenServer`, `:erlang` functions) unless there's an extremely compelling reason for abstraction.
*   **Mox:** Use Mox for creating mock implementations of behaviours, particularly when injecting dependencies for testing.

#### 3.5. Configuration Management

*   **GenServer for Runtime Config:** Use a GenServer (e.g., `Services.ConfigServer`) for managing dynamic configuration that can be updated at runtime.
*   **Validation:** Configuration validation logic **MUST** reside in a pure Layer 2 module (e.g., `Validation.ConfigValidator`). The `ConfigServer` will call these validation functions.
*   **API Contract:** The public API for configuration (e.g., `YourApp.Foundation.Config` implementing `Contracts.Configurable`) **MUST** adhere to standard return tuples (Section 3.1).
    *   `get() :: {:ok, Config.t()} | {:error, Error.t()}`
    *   `get(path :: [atom()]) :: {:ok, term()} | {:error, Error.t()}`
    *   `update(path :: [atom()], value :: term()) :: {:ok, Config.t()} | {:error, Error.t()}` (returns new config)
    *   `validate_config_struct(config :: Config.t()) :: :ok | {:error, Error.t()}` (if it only checks)
    *   `validate_and_normalize_config_struct(config :: Config.t()) :: {:ok, Config.t()} | {:error, Error.t()}` (if it transforms/normalizes)

### 4. Testing Strategy

1.  **Unit Tests (for Layer 2 - Pure Logic):**
    *   Focus: Test pure functions in isolation.
    *   Tools: `ExUnit`.
    *   Target: `Validation.*` and `Logic.*` modules.
    *   High coverage is expected.

2.  **Property-Based Tests (for Layer 2 - Complex Pure Logic/Validation):**
    *   Focus: Test function properties over a wide range of generated inputs.
    *   Tools: `StreamData`.
    *   Target: Especially useful for validation functions and complex data transformations in `Validation.*` and `Logic.*`.

3.  **Contract Tests (for Layer 3 - Behaviour Implementations):**
    *   Focus: Verify that a module correctly implements a defined behaviour.
    *   Tools: `ExUnit`, potentially shared test modules defining contract assertions.
    *   Example: A test suite that takes any module implementing `Contracts.Configurable` and ensures it behaves as expected.
        ```elixir
        # test/support/configurable_contract.ex
        defmodule YourApp.ConfigurableContract do
          use ExUnit.CaseTemplate

          using do
            quote do
              # ... tests for get/0, get/1, update/2 using @implementation_module
              # Asserting {:ok, _} | {:error, _} returns and typespecs
            end
          end
        end

        # test/your_app/foundation/config_test.exs
        defmodule YourApp.Foundation.ConfigTest do
          use ExUnit.Case, async: true
          use YourApp.ConfigurableContract

          @implementation_module YourApp.Foundation.Config
          # ... regular unit/integration tests for Config module
        end
        ```

4.  **Integration Tests (for Layer 3 - Services & Public APIs):**
    *   Focus: Test the interaction of components, including GenServers, database interactions, and interaction between Layer 3 public APIs and their underlying services.
    *   Tools: `ExUnit`. Mox for mocking external dependencies or other services not under direct test.
    *   Target: `Services.*` (testing GenServer lifecycle, concurrency, state changes) and Public API modules (testing end-to-end flows through that API).

5.  **Mox Usage:**
    *   **Primarily for:**
        *   External dependencies (HTTP clients, third-party APIs defined by a behaviour).
        *   Testing different implementations of your own behaviours (e.g., an in-memory vs. a DB-backed repo).
        *   When a Layer 3 module has a dependency (injected via DI) on another service defined by a behaviour, and you want to test the calling module in isolation.
    *   **Not for:** Mocking your own tightly-coupled core modules within the same feature if DI isn't already used for other reasons. Prefer testing them together in an integration test or use DI if decoupling is truly desired.

### 5. Telemetry

*   Integrate `:telemetry` for emitting events related to key operations, errors, and performance metrics.
*   Events should be well-defined and documented.
*   Use structured metadata with events.
*   Telemetry event emission is a side-effect; if the emission itself can fail (unlikely with `:telemetry`), it should follow return standards (Section 3.1), typically `:ok | {:error, reason}`.

### 6. Decision Guidelines & FAQs Addressed

1.  **`validate/1` function return value:**
    *   If validation *only checks* and does not transform the data: `validate(data) :: :ok | {:error, Error.t()}`
    *   If validation *transforms or normalizes* the data: `validate(data) :: {:ok, validated_data} | {:error, Error.t()}`
    *   Be explicit in the function name if necessary (e.g., `normalize_and_validate_config/1`).

2.  **Granularity of Error Types (`Error.t().code`):**
    *   Strive for a balance. Codes should be granular enough to allow programmatic decisions by callers but not so numerous that they become unmanageable.
    *   Always return the full `Error.t()` struct.
    *   Provide helper functions for pattern matching common error codes if needed (e.g., `Error.validation_error?(error)`).

3.  **Validation Logic Location:**
    *   Validation logic **MUST** be in pure Layer 2 functions. GenServers (Layer 3) **MUST** call these pure functions for validation.

4.  **Handling `:not_updatable` vs `Error.t()` type inconsistencies:**
    *   All functional errors **MUST** use `{:error, %Error.t()}`. Legacy atoms like `:not_updatable` must be mapped to an appropriate `Error.t{code: :not_updatable, ...}`.

### 7. Document Review & Evolution

This standard is a living document. It will be reviewed periodically (e.g., quarterly or as significant new patterns emerge) and updated by [Team/Committee Responsible] to reflect evolving best practices and project needs. Feedback and suggestions for improvement are encouraged.

---

This document provides a strong, actionable standard. You'll want to replace bracketed placeholders like `[Your Organization/Project Name]` and `[Team/Committee Responsible]` and potentially flesh out `Error.t().code` examples specific to your domain. Good luck!
