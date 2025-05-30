Okay, this is a significant but logical step. Decomposing ElixirScope into modular libraries is crucial for maintainability, testability, and focused development, especially before integrating its core intelligence into a Tidewave fork.

Given the extensive documentation (existing `Repomix` structure and the forward-looking `CPG_*.md` files), we can design a robust set of independent projects/libraries. The goal is to create components that `TidewaveScope` can then depend on and orchestrate.

Here's a detailed decomposition plan:

**Core Principles for Decomposition:**

1.  **Single Responsibility:** Each library should have a clear, focused purpose.
2.  **Clear APIs:** Interactions between libraries should be through well-defined public APIs.
3.  **Manageable Dependencies:** Aim for a directed acyclic graph of dependencies between these new libraries.
4.  **Testability:** Each library should be testable in isolation (as much as possible).
5.  **Future-Proofing:** Account for the advanced CPG functionalities as integral parts of the relevant libraries.

---

## ElixirScope Libraries Decomposition

Here's the proposed set of libraries, their primary responsibilities based on your documentation, and key modules they would contain:

**1. `elixir_scope_utils` (Foundational Utility Library)**

*   **Purpose:** Core, low-level utilities used across multiple ElixirScope components. Does not depend on other ElixirScope libraries.
*   **Key Modules (from `elixir_scope/utils.ex`):**
    *   `ElixirScope.Utils` (timestamp generation, ID generation, data inspection/truncation, performance measurement helpers, formatting utilities, validation helpers).
*   **CPG Docs Impact:** None directly, but its utilities might be used by CPG algorithm implementations.

**2. `elixir_scope_config` (Core Configuration Management)**

*   **Purpose:** Manages loading, validation, and runtime access to all ElixirScope configurations.
*   **Key Modules (from `elixir_scope/config.ex` and implied by other configs):**
    *   `ElixirScope.Config` (main configuration GenServer and API).
    *   Specific configuration modules for other major components if they become complex enough (e.g., `ElixirScope.ASTRepository.Config` from `ast_repository/config.ex` for AST Repo specific settings would move here or be managed by this).
*   **CPG Docs Impact:** Will need to incorporate configuration sections from `CPG_PRD.md` (NFRs implying configurable thresholds) and other CPG docs defining tunable parameters.

**3. `elixir_scope_events` (Core Event Definitions)**

*   **Purpose:** Defines all core event structures used by ElixirScope.
*   **Key Modules (from `elixir_scope/events.ex`):**
    *   `ElixirScope.Events` (base event struct, specific event structs like `FunctionExecution`, `ProcessEvent`, `MessageEvent`, `StateChange`, etc., serialization/deserialization).
*   **CPG Docs Impact:** CPG-related analyses might generate new event types (e.g., pattern match event, smell detected event) that would be defined here.

**4. `elixir_scope_capture_core` (Runtime Event Capture Primitives)**

*   **Purpose:** The immediate runtime components responsible for capturing events from instrumented code and initial buffering.
*   **Key Modules:**
    *   `ElixirScope.Capture.InstrumentationRuntime.*` (all submodules like `Context`, `CoreReporting`, `ASTReporting`, `PhoenixReporting`, `EctoReporting`, `GenServerReporting`, `DistributedReporting`). This is the API called by instrumented code.
    *   `ElixirScope.Capture.Ingestor.*` (all submodules). The first point of contact for raw event data.
    *   `ElixirScope.Capture.RingBuffer`.
*   **CPG Docs Impact:** Minimal direct impact, but `ASTReporting` will be crucial for emitting events with `ast_node_id`s needed for CPG correlation.

**5. `elixir_scope_storage` (Event Storage Layer)**

*   **Purpose:** Provides persistent and/or in-memory storage for captured events.
*   **Key Modules:**
    *   `ElixirScope.Storage.DataAccess` (ETS-based storage with indexing logic).
    *   `ElixirScope.Storage.EventStore` (GenServer wrapper for `DataAccess`).
    *   The existing `elixir_scope/event_store.ex` facade might be part of this or the main `TidewaveScope` app.
*   **CPG Docs Impact:** `CPG_ETS_INTEGRATION.md` discusses ETS table design which is relevant here if events related to CPG analysis are stored.

**6. `elixir_scope_capture_pipeline` (Asynchronous Event Processing)**

*   **Purpose:** Manages the asynchronous processing of events after initial capture.
*   **Key Modules (from `elixir_scope/capture/*`):**
    *   `ElixirScope.Capture.AsyncWriter`.
    *   `ElixirScope.Capture.AsyncWriterPool`.
    *   `ElixirScope.Capture.PipelineManager`.
*   **CPG Docs Impact:** None directly, but processes events that might contain CPG-related `ast_node_id`s.

**7. `elixir_scope_ast_repo` (Static Analysis & Code Repository)**

*   **Purpose:** The heart of static analysis. Manages ASTs, generates CFGs, DFGs, CPGs, and provides querying and pattern matching over this static representation. This library will absorb most of the `CPG_*.md` logic.
*   **Key Modules (from `elixir_scope/ast_repository/*` and CPG docs):**
    *   **Core Repository & Data Structures:**
        *   `ElixirScope.ASTRepository.Enhanced.Repository` (the GenServer).
        *   `ElixirScope.ASTRepository.Enhanced.EnhancedModuleData`, `EnhancedFunctionData`.
        *   `ElixirScope.ASTRepository.Enhanced.CFGData`, `DFGData`, `CPGData` (and their sub-structs like `CFGNode`, `CPGNode`, etc.).
        *   `ElixirScope.ASTRepository.Enhanced.ComplexityMetrics`, `SharedDataStructures`, `SupportingStructures`, `VariableData`.
    *   **Parsing & Initial Analysis:**
        *   `ElixirScope.ASTRepository.Parser` (the enhanced version, potentially incorporating `NodeIdentifier` logic).
        *   `ElixirScope.ASTRepository.NodeIdentifier`.
        *   `ElixirScope.ASTRepository.ASTAnalyzer`.
    *   **Graph Generation:**
        *   `ElixirScope.ASTRepository.Enhanced.CFGGenerator` (and its submodules like `ExpressionProcessors`, `ControlFlowProcessors`, etc.).
        *   `ElixirScope.ASTRepository.Enhanced.DFGGenerator` (and its submodules).
        *   `ElixirScope.ASTRepository.Enhanced.CPGBuilder` (and its submodules).
    *   **CPG Algorithms (NEW, from CPG_*.md):**
        *   `ElixirScope.ASTRepository.Enhanced.CPGMath` (implementing APIs from `CPG_MATH_API.MD`).
        *   `ElixirScope.ASTRepository.Enhanced.CPGSemantics` (implementing APIs from `CPG_SEMANTICS_API.MD`).
    *   **Repository Management:**
        *   `ElixirScope.ASTRepository.Enhanced.ProjectPopulator` (and its submodules).
        *   `ElixirScope.ASTRepository.Enhanced.FileWatcher`.
        *   `ElixirScope.ASTRepository.Enhanced.Synchronizer`.
    *   **Querying & Pattern Matching:**
        *   `ElixirScope.ASTRepository.QueryBuilder` (and its submodules, enhanced as per `CPG_QUERY_ENHANCEMENTS.MD`).
        *   `ElixirScope.ASTRepository.QueryExecutor` (or integrated into `QueryBuilder` / `Repository`).
        *   `ElixirScope.ASTRepository.PatternMatcher` (and its submodules, enhanced as per `CPG_PATTERN_DETECTION_ADVANCED.MD`).
    *   **Optimization & Memory:**
        *   `ElixirScope.ASTRepository.MemoryManager` (and its submodules).
        *   `ElixirScope.ASTRepository.PerformanceOptimizer` (and its submodules).
        *   Logic from `CPG_OPTIMIZATION_STRATEGIES.MD` integrated here.
    *   **Configuration:** `ElixirScope.ASTRepository.Config` (if not part of `elixir_scope_config`).
*   **CPG Docs Impact:** This library is the primary home for almost all CPG-related logic described in the PRD, API docs, and strategy docs. `CPG_ETS_INTEGRATION.MD` directly informs the `EnhancedRepository`'s storage backend. Test lists (`CPG-*.md`) will drive TDD for modules here.

**8. `elixir_scope_correlator` (Runtime to Static Correlation)**

*   **Purpose:** Manages the crucial link between runtime events (from `elixir_scope_capture_core`) and static code structures (from `elixir_scope_ast_repo`).
*   **Key Modules (from `elixir_scope/ast_repository/runtime_correlator/*` and `elixir_scope/capture/event_correlator.ex`):**
    *   `ElixirScope.ASTRepository.RuntimeCorrelator` (GenServer, managing correlation state).
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.EventCorrelator` (core correlation logic).
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.ContextBuilder`.
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.TraceBuilder`.
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.CacheManager`.
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.Config`.
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.Types`.
    *   `ElixirScope.ASTRepository.RuntimeCorrelator.Utils` (may merge with `elixir_scope_utils`).
    *   The existing `ElixirScope.Capture.EventCorrelator` seems to have overlapping responsibilities and should be merged/refactored into this new library.
*   **CPG Docs Impact:** The `ast_node_id` is the key. This library uses these IDs to link events to CPG nodes. The quality of its output is fundamental for many CPG-enhanced features.

**9. `elixir_scope_debugger_features` (Advanced Debugging Engine)**

*   **Purpose:** Implements advanced debugging features like structural breakpoints, data flow breakpoints, and semantic watchpoints, leveraging the correlator and AST repo.
*   **Key Modules (from `elixir_scope/capture/enhanced_instrumentation/*`):**
    *   `ElixirScope.Capture.EnhancedInstrumentation` (GenServer, main engine for these features).
    *   `ElixirScope.Capture.EnhancedInstrumentation.ASTCorrelator` (specific correlation needs for breakpoints).
    *   `ElixirScope.Capture.EnhancedInstrumentation.BreakpointManager`.
    *   `ElixirScope.Capture.EnhancedInstrumentation.WatchpointManager`.
    *   `ElixirScope.Capture.EnhancedInstrumentation.EventHandler`.
    *   `ElixirScope.Capture.EnhancedInstrumentation.Storage` (ETS for breakpoint/watchpoint definitions).
    *   `ElixirScope.Capture.EnhancedInstrumentation.DebuggerInterface`.
    *   `ElixirScope.Capture.EnhancedInstrumentation.Utils` (may merge with `elixir_scope_utils`).
*   **CPG Docs Impact:** Data flow breakpoints and semantic watchpoints will heavily rely on DFG/CPG data from `elixir_scope_ast_repo`. Structural breakpoints can use CPG patterns.

**10. `elixir_scope_temporal_debug` (Time-Travel Debugging)**

*   **Purpose:** Enables time-travel debugging capabilities, including state reconstruction.
*   **Key Modules (from `elixir_scope/capture/*`):**
    *   `ElixirScope.Capture.TemporalStorage` (specialized event storage).
    *   `ElixirScope.Capture.TemporalBridge` (bridge to `TemporalStorage`).
    *   `ElixirScope.Capture.TemporalBridgeEnhancement` (integrates AST/CPG context into time-travel, and its submodules: `ASTContextBuilder`, `CacheManager`, `EventProcessor`, `StateManager`, `TraceBuilder`, `Types`).
*   **CPG Docs Impact:** `TemporalBridgeEnhancement` will use the `elixir_scope_correlator` and `elixir_scope_ast_repo` to enrich reconstructed states and traces with CPG context.

**11. `elixir_scope_ai` (Artificial Intelligence Layer)**

*   **Purpose:** Contains all AI models, LLM integration, and AI-driven analysis logic.
*   **Key Modules (from `elixir_scope/ai/*`):**
    *   `ElixirScope.AI.LLM.*` (Client, Config, Provider, Response, and provider implementations).
    *   `ElixirScope.AI.Analysis.IntelligentCodeAnalyzer`.
    *   `ElixirScope.AI.CodeAnalyzer` (the older one, may be refactored or merged).
    *   `ElixirScope.AI.ComplexityAnalyzer`.
    *   `ElixirScope.AI.PatternRecognizer`.
    *   `ElixirScope.AI.Predictive.ExecutionPredictor`.
    *   `ElixirScope.AI.Bridge` (facade for AI components to access other ElixirScope data).
    *   `ElixirScope.CompileTime.Orchestrator` (AI for instrumentation planning).
*   **CPG Docs Impact:** This library is a major consumer of CPG-derived features as outlined in `CPG_AI_ML_FEATURES.MD`. The `AI.Bridge` will be crucial for providing CPG context to AI models.

**12. `elixir_scope_compiler` (AST Instrumentation)**

*   **Purpose:** Handles the compile-time AST transformation to inject instrumentation calls.
*   **Key Modules:**
    *   `ElixirScope.Compiler.MixTask` (the Mix compiler task itself).
    *   `ElixirScope.AST.Transformer`.
    *   `ElixirScope.AST.EnhancedTransformer`.
    *   `ElixirScope.AST.InjectorHelpers`.
    *   `ElixirScope.ASTRepository.InstrumentationMapper`.
*   **CPG Docs Impact:** The `EnhancedTransformer` will be responsible for injecting calls that include the stable `ast_node_id`s generated by the `elixir_scope_ast_repo`'s parsing phase.

**13. `elixir_scope_phoenix` (Optional Phoenix Integration)**

*   **Purpose:** Provides specific integration points and telemetry handlers for Phoenix applications.
*   **Key Modules (from `elixir_scope/phoenix/integration.ex`):**
    *   `ElixirScope.Phoenix.Integration` (telemetry handlers for requests, LiveView, Channels, Ecto).
*   **CPG Docs Impact:** Can provide valuable context to CPG analysis by tagging CPG nodes related to Phoenix constructs, which `CPGSemantics` can then use.

**14. `elixir_scope_distributed` (Optional Distributed Tracing)**

*   **Purpose:** Handles coordination and event synchronization for ElixirScope running in a distributed Elixir environment.
*   **Key Modules (from `elixir_scope/distributed/*`):**
    *   `ElixirScope.Distributed.GlobalClock`.
    *   `ElixirScope.Distributed.EventSynchronizer`.
    *   `ElixirScope.Distributed.NodeCoordinator`.
*   **CPG Docs Impact:** Distributed CPG analysis is a future consideration but having this foundation is good.

**15. `TidewaveScope` (The Forked Application - Main Orchestrator)**

*   **Purpose:** This is not a library but the resulting application after forking Tidewave. It will:
    *   Depend on the above ElixirScope libraries.
    *   Provide the main OTP application structure (modified from `elixir_scope/application.ex`).
    *   House the `TidewaveScope.Plug`.
    *   Contain the modified `TidewaveScope.MCP.Server` and tools.
    *   Manage the overall lifecycle and configuration of ElixirScope services.
    *   Expose ElixirScope's capabilities via its MCP tools.
    *   The top-level `elixir_scope.ex` facade module would likely live here, providing the primary user-facing API for ElixirScope features that aren't directly MCP tools.

---

**Summary of Decomposition:**

*   **Core & Utilities:** `elixir_scope_utils`, `elixir_scope_config`, `elixir_scope_events`
*   **Capture & Storage:** `elixir_scope_capture_core`, `elixir_scope_storage`, `elixir_scope_capture_pipeline`
*   **Static Analysis Engine:** `elixir_scope_ast_repo` (this is where CPG logic primarily lives)
*   **Runtime-Static Link:** `elixir_scope_correlator`
*   **Debugging Features:** `elixir_scope_debugger_features`, `elixir_scope_temporal_debug`
*   **Intelligence:** `elixir_scope_ai`
*   **Build Integration:** `elixir_scope_compiler`
*   **Optional Integrations:** `elixir_scope_phoenix`, `elixir_scope_distributed`
*   **Main Application (Fork):** `TidewaveScope`

This decomposition provides a clear separation of concerns, making the system more modular and easier to develop, test, and maintain. The `elixir_scope_ast_repo` becomes the central powerhouse for static analysis, including all the advanced CPG functionalities. `TidewaveScope` then acts as the user-facing (via AI assistant) application that leverages these powerful underlying libraries.
