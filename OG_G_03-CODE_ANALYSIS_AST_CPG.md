## ElixirScope Concurrency: Code Analysis Pipeline (AST, Graph, CPG, Analysis)

The core of ElixirScope's static analysis capabilities involves a pipeline transforming source code into actionable insights. This pipeline, encompassing the AST, Graph, CPG, and Analysis layers, must be highly performant and scalable to handle large codebases efficiently. BEAM/OTP concurrency patterns are essential to achieving this.

The overall philosophy is to parallelize work at the largest independent units possible (e.g., per file/module) and then further parallelize stages within those units where feasible.

### 1. AST Layer (Parsing & Repository)

This layer is responsible for parsing Elixir source files into Abstract Syntax Trees (ASTs) and managing a repository of these ASTs.

*   **Parallel Parsing:**
    ElixirScope can parse multiple Elixir files or modules concurrently. Given a list of file paths or module names, `Task.async_stream/5` is an excellent choice for this. It allows concurrent execution of a parsing function for each file, with controlled concurrency and error handling.

    ```elixir
    defmodule ElixirScope.AST.ParserOrchestrator do
      alias ElixirScope.AST.Parser # Assumed module for parsing a single file

      def parse_files_concurrently(file_paths, opts \\ []) do
        # Max concurrency can be tuned, e.g., number of schedulers
        max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
        timeout = Keyword.get(opts, :timeout, 60_000) # 60 seconds per file

        file_paths
        |> Task.async_stream(
          &ElixirScope.AST.Parser.parse_file_to_ast(&1), # Function to parse one file
          max_concurrency: max_concurrency,
          ordered: false, # Results can be processed as they complete
          timeout: timeout,
          on_timeout: :kill_task # Or a custom handling
        )
        |> Stream.map(fn
          {:ok, ast_result} ->
            # Store successful AST or handle it
            # e.g., ElixirScope.AST.Repository.store(ast_result.file_path, ast_result.ast)
            {:ok, ast_result.file_path}
          {:exit, {reason, _stacktrace}} ->
            # Log error for this specific file, continue with others
            Logger.error("Failed to parse file due to exit: #{inspect(reason)}")
            {:error, :parsing_exit}
          {:error, reason} ->
            Logger.error("Failed to parse file: #{inspect(reason)}")
            {:error, reason}
        end)
        |> Enum.to_list() # Or stream further
      end
    end
    ```
    Each call to `ElixirScope.AST.Parser.parse_file_to_ast/1` runs in a separate, lightweight BEAM process managed by the `Task` system.

*   **AST Repository Management:**
    Once parsed, ASTs need to be stored for access by subsequent layers (like CPG).
    *   **`GenServer` Approach:**
        A single `GenServer` could manage an in-memory map of `file_path => ast`.
        *   *Concurrent Access:* Reads (`get_ast/1`) and writes (`store_ast/2`) would be serialized through `GenServer.call/3`. This ensures consistency but can become a bottleneck if AST access is very frequent and contentious from many parallel CPG builders.
        *   *Trade-offs:* Simpler to implement complex logic (e.g., cache eviction, versioning). Prone to bottlenecks.
    *   **ETS Approach:**
        An ETS table (or multiple tables) can store the ASTs. `ets:insert/2` for writes, `ets:lookup/2` for reads.
        *   *Concurrent Access:* ETS allows concurrent reads by default. Writes can be managed using `:write_concurrency` (automatic sharding of locks) or by having dedicated writer processes (if updates are less frequent).
        *   *Ownership:* The `AST.ParserOrchestrator` or individual parsing `Task`s could "own" writing their results to ETS. Higher layers would primarily read.
        *   *Trade-offs:* Significantly better concurrent read performance. Requires more careful management of data lifecycle, table ownership, and potential write contention if many processes update the *same* AST (less likely for raw ASTs). For ElixirScope, given that ASTs are foundational and read by many subsequent processes, **an ETS-backed store is generally preferred for performance, potentially with a `GenServer` acting as an API façade or manager for more complex operations like sweeping or bulk loading.**

### 2. Graph Layer (Algorithms)

This layer provides graph algorithms used by the CPG and Analysis layers.

*   **Parallelizing Graph Algorithms:**
    Many graph algorithms can be parallelized, especially on large graphs like a full CPG.
    *   **Independent Sub-computations:** If an algorithm involves processing nodes or edges independently (e.g., calculating local metrics for each node), `Task.async_stream` can be used.
    *   **Divide and Conquer:** Some algorithms can be broken down. For example, finding all paths between multiple pairs of nodes could parallelize each pathfinding operation. `Task.async/await` is suitable for a known set of such sub-tasks.
        ```elixir
        defmodule ElixirScope.Graph.Pathfinder do
          def find_all_paths_concurrently(graph, source_target_pairs) do
            tasks =
              Enum.map(source_target_pairs, fn {source, target} ->
                Task.async(fn ->
                  # This would be the actual pathfinding logic on the graph
                  ElixirScope.Graph.Algorithms.find_shortest_path(graph, source, target)
                end)
              end)

            Task.await_many(tasks, :infinity)
          end
        end
        ```
    *   **Parallel Traversals:** For algorithms like community detection or influence spread, traversals might be initiated from multiple points in parallel.
    *   **Data Parallelism:** If the graph is very large, it could be partitioned, and algorithms run on partitions concurrently, followed by a merge step. This is more complex and depends heavily on the algorithm.

### 3. CPG Layer (Construction)

This layer builds the Code Property Graph, which involves creating Control Flow Graphs (CFGs), Data Flow Graphs (DFGs), Call Graphs, etc., from ASTs and inter-procedural information.

*   **Parallel Construction (Per Module/File):**
    The most significant parallelism comes from processing modules/files independently. An orchestrator (e.g., a `GenServer` or a `Supervisor` starting dynamic tasks) can manage CPG construction for each module in parallel.
    ```elixir
    defmodule ElixirScope.CPG.BuilderOrchestrator do
      use GenServer

      # ... GenServer setup ...

      def build_cpg_for_project(module_asts_map) do
        # module_asts_map: %{module_name => ast_data}
        Task.Supervisor.async_stream_nolink(
          MyCPGTaskSupervisor, # Name of a Task.Supervisor
          module_asts_map,
          fn {module_name, ast_data} ->
            # ElixirScope.CPG.ModuleBuilder.build/2 would construct the CPG for a single module
            ElixirScope.CPG.ModuleBuilder.build(module_name, ast_data)
          end,
          # ... other Task.Supervisor options ...
        )
        |> Stream.map(fn {:ok, cpg_result} -> cpg_result end) # Handle errors
        |> Enum.to_list()
      end

      # ... GenServer callbacks for managing state, e.g., storing completed CPGs ...
    end
    ```
    Each `ElixirScope.CPG.ModuleBuilder.build/2` call runs in its own process.

*   **Pipelined Stages:**
    CPG construction for a single module might involve stages: AST -> CFG -> DFG -> inter-procedural connections.
    *   If these stages are largely independent or have clear data dependencies, they *could* be pipelined. For instance, after the CFG for a function is built, DFG construction for that function could begin while the CFG for the next function is being built.
    *   `GenStage` is the idiomatic OTP solution for such pipelines. A pipeline could look like:
        `FileParser (Producer)` -> `ASTProcessor (ProducerConsumer)` -> `CFGBuilder (ProducerConsumer)` -> `DFGBuilder (Consumer)`
    *   Within a single module's CPG construction, if stages like CFG and DFG generation for different functions are independent enough, `Task.async/await` can be used to parallelize them.

### 4. Analysis Layer (Architectural Analysis, Patterns)

This layer consumes CPGs (and potentially ASTs/Graphs) to perform various analyses.

*   **Concurrent Analysis Tasks:**
    Different types of analyses (e.g., smell detection, metric calculation, pattern recognition) can often run concurrently on the same CPG or different CPGs.
    *   An `AnalysisOrchestrator` `GenServer` could receive a CPG and dispatch various analysis tasks using a `Task.Supervisor`.
    ```elixir
    defmodule ElixirScope.Analysis.Orchestrator do
      use GenServer
      alias ElixirScope.Analysis.{SmellDetector, MetricsCalculator, PatternMatcher}

      # ... GenServer setup ...

      def analyze_cpg(cpg_data, analysis_types \\ [:smells, :metrics, :patterns]) do
        # Call the GenServer to start analysis
        GenServer.call(__MODULE__, {:analyze, cpg_data, analysis_types})
      end

      @impl GenServer
      def handle_call({:analyze, cpg_data, analysis_types}, _from, state) do
        tasks = []
        tasks = if :smells in analysis_types,
          do: [Task.Supervisor.async_nolink(MyAnalysisTaskSupervisor, SmellDetector, :find_smells, [cpg_data]) | tasks],
          else: tasks
        tasks = if :metrics in analysis_types,
          do: [Task.Supervisor.async_nolink(MyAnalysisTaskSupervisor, MetricsCalculator, :calculate, [cpg_data]) | tasks],
          else: tasks
        tasks = if :patterns in analysis_types,
          do: [Task.Supervisor.async_nolink(MyAnalysisTaskSupervisor, PatternMatcher, :detect, [cpg_data]) | tasks],
          else: tasks

        results = Task.await_many(tasks, 300_000) # 5 min timeout for all analyses
        # Aggregate results and reply
        {:reply, {:ok, aggregate_analysis_results(results)}, state}
      end
      # ...
    end
    ```

*   **Long-Running Background Analysis:**
    If a particular analysis is very time-consuming (e.g., complex whole-program analysis or AI-driven deep dives), it should be managed as a background job.
    *   The client (e.g., a user interface or another service) would initiate the analysis via a `GenServer`.
    *   This `GenServer` then starts a `Task` (linked or monitored) under a `Task.Supervisor` or even a dedicated `Supervisor` if the tasks are critical and need specific restart strategies.
    *   The `GenServer` can reply immediately with a `{:ok, task_id}` or similar, and the client can poll for status or receive a message upon completion.

### 5. Data Flow and Dependencies

*   **Passing Data Between Layers:**
    *   **Initial Data (Files):** A list of file paths.
    *   **ASTs:**
        *   If using an ETS repository for ASTs, CPG builders read from ETS. `file_path` or `module_name` is the key.
        *   Alternatively, parsed ASTs can be passed via messages from parsing tasks to a CPG orchestrator.
    *   **CPGs:**
        *   Similar to ASTs, CPGs for modules can be stored in ETS or passed via messages to an Analysis orchestrator. Given their complexity and size, ETS might be better for decoupling and allowing multiple analysis types to access them.
        *   A `CPGRegistry` `GenServer` could manage references or paths to CPG data stored elsewhere (e.g., ETS, filesystem for very large graphs).
    *   **Analysis Results:** Typically smaller, can be returned via messages or stored in a results-focused `GenServer` or database.

*   **Managing Dependencies:**
    If CPG construction for module B depends on the AST (or partial CPG, e.g., call signatures) of module A (common for resolving inter-procedural calls):
    *   **Orchestration:** A master orchestrator for the entire project's analysis needs to understand module dependencies (e.g., from Elixir's compilation manifest or by analyzing imports/aliases).
    *   **Phase-Based Processing:**
        1.  Phase 1: Parse all ASTs concurrently.
        2.  Phase 2: Build intra-procedural CPG parts (CFGs, DFGs) for all modules concurrently.
        3.  Phase 3: Once all module CPG "skeletons" are ready, perform inter-procedural analysis (e.g., build call graph edges, propagate data flow across calls). This phase itself can be parallelized for different connections.
    *   **`Task.async/await` for Dependencies:** If Module B's CPG builder knows it needs Module A's AST, it can `Task.await` a task that ensures Module A's AST is available in the repository.
    *   **PubSub or explicit messaging:** AST parsers/CPG builders could publish "AST ready" or "CPG part ready" events, and dependent builders subscribe to these.

### 6. Error Handling and Fault Tolerance

*   **Isolate Failures:** The primary goal is that an error in processing one file/module should not halt the analysis of others.
    *   **Supervisors for Workers:**
        *   When using `Task.async_stream` or `Task.Supervisor.async_stream_nolink`, the stream processing handles individual task failures gracefully. The overall stream can continue.
        *   If spawning `GenServer`s per module for CPG construction, these should be under a `Supervisor` (likely with a `:simple_one_for_one` strategy if they are temporary or `:one_for_one` if long-lived).
    *   **Granular Error Reporting:** Each parallel unit (file parser, module CPG builder, analysis task) should report its own success or failure. The orchestrator collects these and can provide a summary (e.g., "100 modules processed, 98 successful, 2 failed").

*   **Supervision Strategies:**
    *   The main orchestrator for parsing/CPG/analysis for a project could be a `GenServer`. If it crashes, the entire project analysis might need to be restarted (or resumed if state is persisted). It would be supervised by a higher-level application supervisor, likely with `:one_for_one` or `:rest_for_one` if it's part of a larger job processing system.
    *   Supervisors managing pools of `Task`s (like `MyCPGTaskSupervisor` or `MyAnalysisTaskSupervisor`) would typically use `:transient` for tasks (restart only if they fail abnormally, not on normal exit).

*   **Example: Fault-Tolerant File Parsing Orchestrator**
    ```elixir
    defmodule ElixirScope.AST.ParsingSupervisor do
      use Supervisor

      def start_link(arg) do
        Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
      end

      @impl true
      def init(_arg) do
        # Using a simple_one_for_one supervisor allows starting many
        # temporary parsing tasks. Each task is its own process.
        children = [
          %{
            id: :file_parser_worker,
            start: {ElixirScope.AST.FileParserTask, :start_link, []}, # Assuming FileParserTask wraps the parsing logic in a Task
            restart: :transient # Only restart if it crashes, not on normal completion
          }
        ]
        Supervisor.init(children, strategy: :simple_one_for_one, max_restarts: 5, max_seconds: 60)
      end

      # Public API to start a parsing task
      def parse_file(file_path) do
        # Args to pass to the FileParserTask's start_link, which then starts the actual Task.
        Supervisor.start_child(__MODULE__, [file_path])
      end
    end
    ```
    An orchestrator would then call `ElixirScope.AST.ParsingSupervisor.parse_file(path)` for each file. If one parsing task crashes, the `simple_one_for_one` supervisor ensures it doesn't affect others. The orchestrator would need to monitor these tasks or receive completion/failure messages.

By strategically applying these OTP patterns, ElixirScope can build a highly concurrent and resilient code analysis pipeline capable of processing large codebases efficiently, providing developers with timely and accurate insights.