Okay, let's detail the public APIs, potential behaviours, and shared data structures for each of the `elixir_scope_` libraries. This will serve as a foundation for your `DESIGN.MD` files and inter-component contracts.

We'll focus on defining the "what" (the interface) rather than the "how" (the implementation details).

---

## ElixirScope Libraries: Public APIs, Behaviours, and Data Structures

**Shared Data Structure Libraries First:**

These libraries will define structs and types used by many other ElixirScope components.

**1. `elixir_scope_utils`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Utils`:
        *   `monotonic_timestamp() :: integer()`
        *   `wall_timestamp() :: integer()`
        *   `format_timestamp(timestamp_ns :: integer()) :: String.t()`
        *   `measure(fun :: (() -> any())) :: {any(), duration_ns :: integer()}`
        *   `generate_id() :: integer() | String.t()` (decide on a consistent ID format)
        *   `generate_correlation_id() :: String.t()`
        *   `id_to_timestamp(id :: integer()) :: integer()` (if using integer-based sortable IDs)
        *   `safe_inspect(term :: any(), opts :: keyword()) :: String.t()`
        *   `truncate_if_large(term :: any(), max_size :: non_neg_integer()) :: any() | {:truncated, non_neg_integer(), String.t()}`
        *   `truncate_data(term :: any(), max_size :: non_neg_integer()) :: any() | {:truncated, non_neg_integer(), String.t()}` (alias or specific version of above)
        *   `term_size(term :: any()) :: non_neg_integer()`
        *   `format_bytes(bytes :: non_neg_integer()) :: String.t()`
        *   `format_duration_ns(nanoseconds :: non_neg_integer()) :: String.t()`
        *   `valid_positive_integer?(value :: any()) :: boolean()`
        *   `valid_percentage?(value :: any()) :: boolean()`
        *   `valid_pid?(pid :: any()) :: boolean()`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** None (primarily functions).

**2. `elixir_scope_events`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Events`:
        *   `new_event(event_type :: atom(), data :: map(), opts :: keyword()) :: ElixirScope.Events.t()`
        *   `serialize(event :: ElixirScope.Events.t()) :: binary()`
        *   `deserialize(binary :: binary()) :: ElixirScope.Events.t()`
        *   Potentially factory functions for common event types if complex enough (e.g., `FunctionExecution.new_call(...)`).
*   **Behaviours Defined/Exposed:** None directly, but event structs act as data contracts.
*   **Shared Data Structures Defined:**
    *   `ElixirScope.Events.t()` (base event struct)
        ```elixir
        defmodule ElixirScope.Events do
          @typedoc "Base event structure."
          @type t :: %__MODULE__{
                  event_id: String.t(),
                  timestamp: non_neg_integer(), # Monotonic nanoseconds
                  wall_time: non_neg_integer(), # System nanoseconds
                  node: atom(),
                  pid: pid(),
                  correlation_id: term() | nil,
                  parent_id: term() | nil,
                  event_type: atom(),
                  data: map(),
                  # CPG Related (optional, added by correlator/enhancer)
                  ast_node_id: String.t() | nil
                }
          defstruct [:event_id, :timestamp, :wall_time, :node, :pid, :correlation_id, :parent_id, :event_type, :data, :ast_node_id]
          # ... (new_event, serialize, deserialize as above)
        end
        ```
    *   `ElixirScope.Events.FunctionExecution.t()` (and other specific event structs like `ProcessEvent`, `MessageEvent`, `StateChange`, `ErrorEvent`, `PerformanceMetric`, etc., as detailed in your `elixir_scope/events.ex`).
        ```elixir
        defmodule ElixirScope.Events.FunctionExecution do
          @typedoc "Event for function execution (call or return)."
          @type t :: %__MODULE__{
                  # Common fields inherited or composed from ElixirScope.Events.t()
                  event_id: String.t(),
                  timestamp: non_neg_integer(),
                  # ...
                  event_type: :function_call | :function_return, # Differentiator
                  data: %{
                    module: module(),
                    function: atom(),
                    arity: non_neg_integer(),
                    args: list() | nil, # Present for :function_call
                    return_value: any() | nil, # Present for :function_return
                    duration_ns: non_neg_integer() | nil, # Present for :function_return
                    caller_pid: pid() | nil, # Present for :function_call
                    exception: {atom(), any(), list()} | nil # Present on error exit
                  }
                }
          defstruct [:event_id, :timestamp, :wall_time, :node, :pid, :correlation_id, :parent_id, :event_type, :data, :ast_node_id]
        end
        ```
    *   (Repeat for `StateChange`, `MessageEvent`, `ProcessEvent`, `ErrorEvent`, `PerformanceMetric`, `VMEvent`, `NodeEvent`, `TableEvent`, `TraceControl`, etc., ensuring all fields from your original `elixir_scope/events.ex` are captured within the `data` map of the main event or as typed structs for the `data` field itself.)

**3. `elixir_scope_ast_structures`**

*   **Public API Modules & Functions:** None (primarily defines structs and types).
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** This library will house the complex data structures related to static analysis.
    *   **From `elixir_scope/ast_repository/enhanced/cfg_data.ex`:**
        *   `ElixirScope.AST.CFGData.t()`, `CFGNode.t()`, `CFGEdge.t()`
        *   `ElixirScope.AST.PathAnalysis.t()`, `Path.t()`, `LoopAnalysis.t()`, `Loop.t()`, `BranchCoverage.t()`
    *   **From `elixir_scope/ast_repository/enhanced/dfg_data.ex`:**
        *   `ElixirScope.AST.DFGData.t()`, `VariableVersion.t()`, `Definition.t()`, `Use.t()`, `DataFlow.t()`, `PhiNode.t()`
        *   `ElixirScope.AST.AnalysisResults.t()` (for DFG), `TypeInfo.t()`, `ShadowInfo.t()`, `OptimizationHint.t()` (DFG specific), `DataFlowComplexity.t()`, `DependencyAnalysis.t()`, `MutationAnalysis.t()`, `PerformanceAnalysis.t()` (DFG specific).
        *   `ElixirScope.AST.DFGNode.t()`, `DFGEdge.t()`, `Mutation.t()` (DFG specific struct versions if different from top-level).
    *   **From `elixir_scope/ast_repository/enhanced/cpg_data.ex`:**
        *   `ElixirScope.AST.CPGData.t()`, `CPGNode.t()`, `CPGEdge.t()`
        *   `ElixirScope.AST.NodeMappings.t()`, `QueryIndexes.t()`, `UnifiedAnalysis.t()`
        *   Specific analysis structs under `UnifiedAnalysis` if they are primarily data containers (e.g., `ElixirScope.AST.SecurityAnalysisResults.t()`, etc.).
    *   **From `elixir_scope/ast_repository/enhanced/shared_data_structures.ex`:**
        *   `ElixirScope.AST.ScopeInfo.t()`
    *   **From `elixir_scope/ast_repository/enhanced/complexity_metrics.ex`:**
        *   `ElixirScope.AST.ComplexityMetrics.t()` (this is the enhanced one).
    *   **From `elixir_scope/ast_repository/enhanced/supporting_structures.ex`:**
        *   All structs defined there, namespaced appropriately, e.g., `ElixirScope.AST.MacroData.t()`, `ElixirScope.AST.TypespecData.t()`, etc.
    *   **From `elixir_scope/ast_repository/enhanced_module_data.ex` & `enhanced_function_data.ex`:**
        *   `ElixirScope.AST.EnhancedModuleData.t()`
        *   `ElixirScope.AST.EnhancedFunctionData.t()`
    *   **From `elixir_scope/ast_repository/module_data.ex` & `function_data.ex` (older versions, for migration or reference):**
        *   `ElixirScope.AST.Legacy.ModuleData.t()`
        *   `ElixirScope.AST.Legacy.FunctionData.t()`
    *   **From `elixir_scope/ast_repository/enhanced/variable_data.ex`:**
        *   `ElixirScope.AST.VariableData.t()`

---

**Remaining Libraries:**

**4. `elixir_scope_config`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Config` (GenServer):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `get() :: ElixirScope.Config.State.t()` (assuming a state struct `ElixirScope.Config.State.t` is defined internally to hold the config map)
        *   `get(path :: list(atom())) :: any()`
        *   `update(path :: list(atom()), value :: any()) :: :ok | {:error, term()}`
        *   `validate(config_map :: map()) :: :ok | {:error, term()}` (utility, might be internal)
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** None publicly, but internally manages its configuration state.

**5. `elixir_scope_capture_core`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Capture.InstrumentationRuntime`: (This module is the *actual* API called by instrumented code. Its functions are numerous as seen in your original `InstrumentationRuntime`.)
        *   Key functions like `report_function_entry/3`, `report_function_exit/3`, `report_ast_function_entry_with_node_id/5`, `report_ast_variable_snapshot/4`, etc.
        *   All Phoenix, Ecto, GenServer reporting functions.
    *   `ElixirScope.Capture.Context`:
        *   `initialize_context() :: :ok`
        *   `clear_context() :: :ok`
        *   `enabled?() :: boolean()`
        *   `current_correlation_id() :: term() | nil`
        *   `with_instrumentation_disabled(fun :: (() -> any())) :: any()`
        *   `generate_correlation_id() :: term()`
        *   `push_call_stack(correlation_id :: term()) :: :ok`
        *   `pop_call_stack() :: :ok`
    *   `ElixirScope.Capture.RingBuffer`:
        *   `new(opts :: keyword()) :: {:ok, ElixirScope.Capture.RingBuffer.t()} | {:error, term()}`
        *   `write(buffer :: ElixirScope.Capture.RingBuffer.t(), event :: ElixirScope.Events.t()) :: :ok | {:error, :buffer_full}`
        *   `read(buffer :: ElixirScope.Capture.RingBuffer.t(), position :: non_neg_integer()) :: {:ok, ElixirScope.Events.t(), non_neg_integer()} | :empty`
        *   `read_batch(buffer :: ElixirScope.Capture.RingBuffer.t(), start_position :: non_neg_integer(), count :: pos_integer()) :: {[ElixirScope.Events.t()], non_neg_integer()}`
        *   `stats(buffer :: ElixirScope.Capture.RingBuffer.t()) :: map()`
        *   `size(buffer :: ElixirScope.Capture.RingBuffer.t()) :: pos_integer()`
        *   `clear(buffer :: ElixirScope.Capture.RingBuffer.t()) :: :ok`
        *   `destroy(buffer :: ElixirScope.Capture.RingBuffer.t()) :: :ok`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:**
    *   `ElixirScope.Capture.RingBuffer.t()` (struct definition)
    *   `ElixirScope.Capture.Context.t()` (internal state struct type)

**6. `elixir_scope_storage`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Storage.EventStore` (GenServer, facade over `DataAccess`):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `store_event(store_ref :: pid() | atom(), event :: ElixirScope.Events.t()) :: :ok | {:error, term()}`
        *   `store_events(store_ref :: pid() | atom(), events :: [ElixirScope.Events.t()]) :: {:ok, non_neg_integer()} | {:error, term()}`
        *   `query_events(store_ref :: pid() | atom(), filters :: keyword() | map()) :: {:ok, [ElixirScope.Events.t()]} | {:error, term()}`
        *   `get_event(store_ref :: pid() | atom(), event_id :: String.t()) :: {:ok, ElixirScope.Events.t()} | {:error, :not_found}`
        *   `get_index_stats(store_ref :: pid() | atom()) :: map()` (delegating to DataAccess stats)
        *   `get_instrumentation_plan(store_ref :: pid() | atom()) :: {:ok, map()} | {:error, :not_found}`
        *   `store_instrumentation_plan(store_ref :: pid() | atom(), plan :: map()) :: :ok | {:error, term()}`
    *   `ElixirScope.Storage.DataAccess` (lower-level ETS manager, API might be mostly internal to `EventStore`):
        *   `new(opts :: keyword()) :: {:ok, ElixirScope.Storage.DataAccess.t()} | {:error, term()}`
        *   (Other functions as needed by `EventStore` for CRUD and querying on ETS tables)
*   **Behaviours Defined/Exposed:** Potentially an `ElixirScope.Storage.Engine` behaviour if you plan multiple storage backends (e.g., ETS, Mnesia, SQL). `DataAccess` would be one implementation.
*   **Shared Data Structures Defined:**
    *   `ElixirScope.Storage.DataAccess.t()` (struct definition)
    *   `ElixirScope.Storage.EventStore.State.t()` (internal GenServer state)

**7. `elixir_scope_capture_pipeline`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Capture.PipelineManager` (Supervisor):
        *   `start_link(opts :: keyword()) :: Supervisor.on_start()`
        *   `get_state(pid :: pid() | atom()) :: map()`
        *   `update_config(pid :: pid() | atom(), new_config :: map()) :: :ok`
        *   `health_check(pid :: pid() | atom()) :: map()`
        *   `get_metrics(pid :: pid() | atom()) :: map()`
        *   `shutdown(pid :: pid() | atom()) :: :ok`
    *   `ElixirScope.Capture.AsyncWriterPool` (GenServer, likely managed by `PipelineManager` but might expose some API):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `scale_pool(pid :: pid() | atom(), new_size :: non_neg_integer()) :: :ok`
        *   `get_worker_assignments(pid :: pid() | atom()) :: map()`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** Internal state structs for the GenServers.

**8. `elixir_scope_ast_repo`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.ASTRepository.EnhancedRepository` (GenServer - the main facade for this library):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `store_module(repo_ref :: pid() | atom(), module_data :: ElixirScope.AST.EnhancedModuleData.t()) :: :ok | {:error, term()}`
        *   `get_module(repo_ref :: pid() | atom(), module_name :: module()) :: {:ok, ElixirScope.AST.EnhancedModuleData.t()} | {:error, :not_found}`
        *   `store_function(repo_ref :: pid() | atom(), function_data :: ElixirScope.AST.EnhancedFunctionData.t()) :: :ok | {:error, term()}`
        *   `get_function(repo_ref :: pid() | atom(), module_name :: module(), function_name :: atom(), arity :: non_neg_integer()) :: {:ok, ElixirScope.AST.EnhancedFunctionData.t()} | {:error, :not_found}`
        *   `get_cfg(repo_ref :: pid() | atom(), module_name :: module(), function_name :: atom(), arity :: non_neg_integer()) :: {:ok, ElixirScope.AST.CFGData.t()} | {:error, term()}`
        *   `get_dfg(repo_ref :: pid() | atom(), module_name :: module(), function_name :: atom(), arity :: non_neg_integer()) :: {:ok, ElixirScope.AST.DFGData.t()} | {:error, term()}`
        *   `get_cpg(repo_ref :: pid() | atom(), module_name :: module(), function_name :: atom(), arity :: non_neg_integer()) :: {:ok, ElixirScope.AST.CPGData.t()} | {:error, term()}`
        *   `clear_repository(repo_ref :: pid() | atom()) :: :ok`
        *   `get_statistics(repo_ref :: pid() | atom()) :: {:ok, map()}`
    *   `ElixirScope.ASTRepository.Enhanced.ProjectPopulator`:
        *   `populate_project(repo_ref :: pid() | atom(), project_path :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}`
        *   `parse_and_analyze_file(file_path :: String.t()) :: {:ok, ElixirScope.AST.EnhancedModuleData.t()} | {:error, term()}` (utility function)
    *   `ElixirScope.ASTRepository.Enhanced.QueryBuilder` (Public API of the query system, not the GenServer itself):
        *   `build_query(query_spec :: map() | keyword()) :: {:ok, ElixirScope.AST.Query.t()} | {:error, term()}` (assuming `Query.t` defined in `elixir_scope_ast_structures`)
        *   `execute_query(repo_ref :: pid() | atom(), query_spec :: map() | ElixirScope.AST.Query.t()) :: {:ok, ElixirScope.AST.QueryResult.t()} | {:error, term()}`
    *   `ElixirScope.ASTRepository.Enhanced.PatternMatcher` (Public API):
        *   `match_ast_pattern(repo_ref :: pid() | atom(), pattern_spec :: map()) :: {:ok, ElixirScope.AST.PatternMatchResult.t()} | {:error, term()}`
        *   `match_cpg_pattern(repo_ref :: pid() | atom(), cpg_data :: ElixirScope.AST.CPGData.t(), pattern_spec :: map()) :: {:ok, ElixirScope.AST.PatternMatchResult.t()} | {:error, term()}`
    *   `ElixirScope.ASTRepository.Enhanced.CPGMath`:
        *   `calculate_centrality(cpg :: ElixirScope.AST.CPGData.t(), node_id :: String.t(), type :: atom()) :: {:ok, float()} | {:error, term()}`
        *   (Other functions as per `CPG_MATH_API.MD`)
    *   `ElixirScope.ASTRepository.Enhanced.CPGSemantics`:
        *   `detect_architectural_smells(cpg :: ElixirScope.AST.CPGData.t(), opts :: keyword()) :: {:ok, list(map())} | {:error, term()}`
        *   (Other functions as per `CPG_SEMANTICS_API.MD`)
*   **Behaviours Defined/Exposed:** None directly, but `EnhancedRepository` is the main service.
*   **Shared Data Structures Defined:** Many internal structs. Primarily consumes structs from `elixir_scope_ast_structures`.

**9. `elixir_scope_compiler`**

*   **Public API Modules & Functions:**
    *   `Mix.Tasks.Compile.ElixirScope`:
        *   `run(argv :: list(String.t())) :: :ok | {:error, term()}` (Mix task interface)
    *   `ElixirScope.AST.Transformer`: (May be exposed for direct use or testing, or kept internal)
        *   `transform_module(ast :: Macro.t(), plan :: map()) :: Macro.t()`
        *   `transform_function(function_ast :: Macro.t(), plan :: map()) :: Macro.t()`
    *   `ElixirScope.AST.EnhancedTransformer`: (As above)
        *   `transform_with_enhanced_instrumentation(ast :: Macro.t(), plan :: map()) :: Macro.t()`
*   **Behaviours Defined/Exposed:** `Mix.Task.Compiler`.
*   **Shared Data Structures Defined:** None (consumes plans, produces ASTs).

**10. `elixir_scope_correlator`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Correlator.RuntimeCorrelator` (GenServer, the main interface from `elixir_scope/ast_repository/runtime_correlator.ex`):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `correlate_event_to_ast(repo_ref :: pid() | atom(), event :: map()) :: {:ok, ElixirScope.Correlator.Types.ast_context()} | {:error, term()}`
        *   `get_runtime_context(repo_ref :: pid() | atom(), event :: map()) :: {:ok, ElixirScope.Correlator.Types.ast_context()} | {:error, term()}`
        *   `enhance_event_with_ast(repo_ref :: pid() | atom(), event :: map()) :: {:ok, ElixirScope.Correlator.Types.enhanced_event()} | {:error, term()}`
        *   `build_execution_trace(repo_ref :: pid() | atom(), events :: list(map())) :: {:ok, ElixirScope.Correlator.Types.execution_trace()} | {:error, term()}`
        *   `get_correlation_stats() :: {:ok, map()}`
        *   `clear_caches() :: :ok`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:**
    *   All types from `elixir_scope/ast_repository/runtime_correlator/types.ex` like `ast_context()`, `enhanced_event()`, `execution_trace()`. These should be moved to a shared types module within this library, e.g., `ElixirScope.Correlator.Types`.

**11. `elixir_scope_debugger_features`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Debugger.Features.EnhancedInstrumentation` (GenServer):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `enable_ast_correlation() :: :ok`
        *   `disable_ast_correlation() :: :ok`
        *   `set_structural_breakpoint(breakpoint_spec :: map()) :: {:ok, String.t()} | {:error, term()}`
        *   `set_data_flow_breakpoint(breakpoint_spec :: map()) :: {:ok, String.t()} | {:error, term()}`
        *   `set_semantic_watchpoint(watchpoint_spec :: map()) :: {:ok, String.t()} | {:error, term()}`
        *   `remove_breakpoint(breakpoint_id :: String.t()) :: :ok`
        *   `list_breakpoints() :: {:ok, map()}`
        *   `get_stats() :: {:ok, map()}`
    *   `ElixirScope.Debugger.Features.DebuggerInterface`:
        *   `trigger_debugger_break(type :: atom(), breakpoint_info :: map(), ast_node_id :: String.t(), context :: map()) :: :ok`
        *   `get_last_break() :: {:ok, map()} | {:error, :not_found}`
        *   `configure_debugger(config :: map()) :: :ok`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** Types for breakpoint/watchpoint specifications and results, e.g., `ElixirScope.Debugger.Features.Types.structural_breakpoint()`.

**12. `elixir_scope_temporal_debug`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.TemporalDebug.TemporalBridgeEnhancement` (GenServer):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `reconstruct_state_with_ast(session_id :: String.t(), timestamp :: non_neg_integer(), ast_repo :: pid() | nil) :: {:ok, ElixirScope.TemporalDebug.Types.ast_enhanced_state()} | {:error, term()}`
        *   `get_ast_execution_trace(session_id :: String.t(), start_time :: non_neg_integer(), end_time :: non_neg_integer()) :: {:ok, ElixirScope.TemporalDebug.Types.ast_execution_trace()} | {:error, term()}`
        *   `get_states_for_ast_node(session_id :: String.t(), ast_node_id :: String.t()) :: {:ok, list(ElixirScope.TemporalDebug.Types.ast_enhanced_state())} | {:error, term()}`
        *   `get_enhancement_stats() :: {:ok, map()}`
        *   `clear_caches() :: :ok`
    *   `ElixirScope.TemporalDebug.TemporalBridge` (original bridge, if kept separate):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `correlate_event(bridge_ref, event) :: :ok` (called by `InstrumentationRuntime`)
        *   `register_as_handler(bridge_ref) :: :ok`
        *   `get_registered_bridge() :: {:ok, pid()} | {:error, :not_registered}`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:**
    *   All types from `elixir_scope/capture/temporal_bridge_enhancement/types.ex` like `ast_enhanced_state()`, `ast_execution_trace()`. These should be in `ElixirScope.TemporalDebug.Types`.

**13. `elixir_scope_ai`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.AI.LLM.Client`:
        *   `analyze_code(code :: String.t(), context :: map()) :: ElixirScope.AI.LLM.Response.t()`
        *   `explain_error(error_message :: String.t(), context :: map()) :: ElixirScope.AI.LLM.Response.t()`
        *   `suggest_fix(problem_description :: String.t(), context :: map()) :: ElixirScope.AI.LLM.Response.t()`
        *   `test_connection() :: ElixirScope.AI.LLM.Response.t()`
    *   `ElixirScope.AI.Analysis.IntelligentCodeAnalyzer` (GenServer):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `analyze_semantics(code_ast :: Macro.t()) :: {:ok, map()} | {:error, atom()}`
        *   `assess_quality(module_code :: String.t()) :: {:ok, map()} | {:error, atom()}`
        *   `suggest_refactoring(code_section :: String.t()) :: {:ok, list(map())} | {:error, atom()}`
    *   `ElixirScope.AI.Predictive.ExecutionPredictor` (GenServer):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `predict_path(module :: module(), function :: atom(), args :: list()) :: {:ok, map()} | {:error, atom()}`
    *   `ElixirScope.AI.Orchestrator` (or `ElixirScope.CompileTime.Orchestrator` if moved):
        *   `generate_plan(target :: module() | {module(), atom(), non_neg_integer()}, opts :: map()) :: {:ok, map()} | {:error, term()}`
        *   `analyze_and_plan(project_path :: String.t()) :: {:ok, map()} | {:error, term()}`
*   **Behaviours Defined/Exposed:**
    *   `ElixirScope.AI.LLM.Provider` (behaviour for different LLM backends).
*   **Shared Data Structures Defined:**
    *   `ElixirScope.AI.LLM.Response.t()`
    *   Structs for analysis results if they become complex.

**14. `elixir_scope_phoenix_integration`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.PhoenixIntegration.Integration`:
        *   `enable() :: :ok`
        *   `disable() :: :ok`
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** None (interacts via telemetry).

**15. `elixir_scope_distributed`**

*   **Public API Modules & Functions:**
    *   `ElixirScope.Distributed.NodeCoordinator` (GenServer):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `setup_cluster(nodes :: list(atom())) :: :ok`
        *   `register_node(node :: atom()) :: :ok | :already_registered`
        *   `get_cluster_nodes() :: list(atom())`
        *   `sync_events() :: {:ok, list(map())} | {:error, term()}`
        *   `distributed_query(query_params :: map()) :: {:ok, list(ElixirScope.Events.t())} | {:error, term()}`
    *   `ElixirScope.Distributed.GlobalClock` (GenServer, if direct interaction is needed beyond NodeCoordinator):
        *   `start_link(opts :: keyword()) :: GenServer.on_start()`
        *   `now() :: {:ok, non_neg_integer()} | non_neg_integer()` (careful with direct call vs GenServer call)
*   **Behaviours Defined/Exposed:** None.
*   **Shared Data Structures Defined:** Internal state structs for GenServers.

This detailed breakdown should provide a solid foundation for defining the `DESIGN.MD` for each library, specifying dependencies in `mix.exs`, and ensuring clear contracts between components. Remember that ExDoc will be invaluable for navigating these public APIs once they are documented with `@doc` and `@spec`.
