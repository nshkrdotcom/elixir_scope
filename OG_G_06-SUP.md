## ElixirScope Supervision Tree Structure

The resilience and fault tolerance of ElixirScope are deeply rooted in OTP's supervision principles. A well-designed supervision tree ensures that failures are isolated, components can be restarted predictably, and the overall system maintains stability even when individual parts encounter issues. This is particularly vital for a debugging and analysis platform that interacts with potentially unstable target applications or external services.

Here's an outline of the likely supervision tree structure within ElixirScope, focusing on key supervisors and the rationale behind their strategies:

**Top-Level Application Supervisor (Implicit)**

*   When ElixirScope starts as an OTP application (e.g., via `ElixirScope.Application.start/2`), it inherently has a top-level application supervisor. This supervisor is responsible for starting and stopping the main components or layers of ElixirScope.

**Layer-Specific Main Supervisors**

Each of ElixirScope's 9 layers should ideally have its own main supervisor. This promotes modularity and fault isolation between layers.

*   **`ElixirScope.Foundation.Application` and `ElixirScope.Foundation.Supervisor`:**
    *   **Supervisor:** `ElixirScope.Foundation.Supervisor` (as defined in `ElixirScope.Foundation.Application`)
    *   **Managed Processes:**
        *   `ElixirScope.Foundation.Services.ConfigServer` (named `ElixirScope.Foundation.Services.ConfigServer`)
        *   `ElixirScope.Foundation.Services.EventStore` (named `ElixirScope.Foundation.Services.EventStore`)
        *   `ElixirScope.Foundation.Services.TelemetryService` (named `ElixirScope.Foundation.Services.TelemetryService`)
        *   `Task.Supervisor` (named `ElixirScope.Foundation.TaskSupervisor`)
    *   **Restart Strategy:** **`:one_for_one`**
        *   **Rationale:** The core services in the Foundation layer (`ConfigServer`, `EventStore`, `TelemetryService`) are largely independent. A crash in `EventStore` (perhaps due to a malformed event causing an unhandled error during processing) should not necessitate restarting `ConfigServer` or `TelemetryService`. The `Task.Supervisor` is also independent; if it crashes (unlikely but possible), it doesn't mean the stateful services need to restart. Each service is critical in its own right, and an individual restart allows it to recover its state (if persisted) or re-initialize.
        *   **Resilience Enhancement:** If `ConfigServer` crashes, other components attempting to read configuration might temporarily use fallback values or cached data (as hinted by `GracefulDegradation`). Upon restart, `ConfigServer` reloads its state. If `EventStore` crashes, new event capture might pause or buffer at the `Capture` layer until `EventStore` is back up. `TelemetryService` crashes might lead to a temporary loss of metric aggregation, but the system can continue operating.

*   **`ElixirScope.AST.ApplicationSupervisor` (Conceptual):**
    *   **Managed Processes:**
        *   `ASTRepositoryManager` (`GenServer` or ETS wrapper for managing parsed ASTs).
        *   `ASTParsingTaskSupervisor` (`Task.Supervisor` for parallel file parsing tasks).
    *   **Restart Strategy:** Likely **`:one_for_one`**. The repository and the task supervisor are distinct concerns.

*   **`ElixirScope.CPG.ApplicationSupervisor` (Conceptual):**
    *   **Managed Processes:**
        *   `CPGOrchestrator` (`GenServer` to manage CPG building for a project).
        *   `CPGModuleBuilderTaskSupervisor` (`Task.Supervisor` for building CPGs of individual modules concurrently).
        *   `CPGStorageManager` (`GenServer` or ETS wrapper for storing/accessing CPGs).
    *   **Restart Strategy:** Could be **`:one_for_one`** for the storage manager and task supervisor. The `CPGOrchestrator` might be `:rest_for_one` if its children (like specific per-project CPG building supervisors) depend on its existence, or if a crash in the orchestrator means the entire CPG building process for that context is invalid.

*   **`ElixirScope.Analysis.ApplicationSupervisor` (Conceptual):**
    *   **Managed Processes:**
        *   `AnalysisJobManager` (`GenServer` to receive analysis requests).
        *   `AnalysisTaskSupervisor` (`Task.Supervisor` to run different analysis types concurrently).
    *   **Restart Strategy:** **`:one_for_one`**. An analysis job manager can restart independently of the task supervisor that executes the individual analysis tasks.

*   **`ElixirScope.Intelligence.ApplicationSupervisor` (Conceptual):**
    *   **Managed Processes:**
        *   `LLMRequestManager` (`GenServer` for managing calls to external LLMs).
        *   `LLMTaskSupervisor` (`Task.Supervisor` for the worker tasks making HTTP calls).
        *   `LocalModelInferencePoolSupervisor` (if applicable, supervising a pool of workers for local ML).
    *   **Restart Strategy:** **`:one_for_one`**. The request manager needs to maintain its queue and active task state; if it crashes, it restarts and potentially re-queues pending work (if persisted) or loses transient requests. The task supervisor just manages workers.

*   **`ElixirScope.Capture.ApplicationSupervisor` (Conceptual):**
    *   **Managed Processes:**
        *   `CaptureController` (`GenServer` to start/stop capture sessions, manage configuration for instrumentation).
        *   Multiple `EventCollector` `GenServer`s (dynamically supervised, perhaps under a `simple_one_for_one` supervisor started by the `CaptureController`).
        *   `CorrelationTaskSupervisor` (`Task.Supervisor` for tasks that correlate runtime events with static CPG data).
    *   **Restart Strategy:** The `CaptureController` could be `:one_for_one`. The supervisor for `EventCollector`s would be `:simple_one_for_one`. A crash in one `EventCollector` (e.g., due to a specific PID it's targeting causing issues) should not affect others.

*   **`ElixirScope.Debugger.ApplicationSupervisor` (Conceptual):**
    *   **Managed Processes:**
        *   `DebuggerMainServer` (`GenServer` handling global debugger state, listing sessions).
        *   `DebugSessionSupervisor` (A `Supervisor` with strategy `:simple_one_for_one` to dynamically start/stop `GenServer`s for each active debug session, e.g., `ElixirScope.Debugger.SessionManager`).
    *   **Restart Strategy:** `:one_for_one` for `DebuggerMainServer`. `:simple_one_for_one` for `DebugSessionSupervisor` is ideal, as each debug session is independent. If a `SessionManager` process crashes, only that session is affected and can be potentially restarted or cleaned up.

**General Principles for System Resilience:**

1.  **Isolation:** By dividing the system into layers and further into distinct services/workers each managed by supervisors, failures are contained. A bug in an AI analysis task won't crash the `ConfigServer`. A problematic debug session won't halt runtime event capture for other purposes.
2.  **Predictable Restarts:** Supervisors ensure that if a critical process dies, it's restarted according to a defined strategy. This provides self-healing capabilities. For stateful `GenServer`s, `init/1` might need to reload state from a persistent store or ETS backup to recover gracefully.
3.  **Let It Crash (Selectively):** For worker processes or temporary tasks (e.g., parsing a single file, running one analysis), if they encounter an unrecoverable error, it's often better to let them crash. The supervisor (or `Task.Supervisor`) will handle the termination, log it, and potentially restart if the strategy dictates (e.g., `:transient` for tasks if they are part of a larger retryable job). The orchestrator that spawned the task can then decide how to proceed (e.g., skip the problematic file, report an error for that unit of work).
4.  **Dynamic Supervision (`simple_one_for_one`):** This is key for features like managing multiple independent debug sessions or handling concurrent requests for LLM insights where each session/request gets its own process. The supervisor doesn't need to know about all children upfront.
5.  **Max Restart Intensity:** Supervisors are configured with `max_restarts` and `max_seconds`. If a child process crashes and restarts too frequently in a short period (indicating a persistent problem like a misconfiguration or a bug in `init/1`), the supervisor will stop attempting to restart that child (and potentially itself, depending on its own supervision strategy). This prevents the system from getting stuck in an endless crash loop consuming resources.
6.  **Graceful Shutdown:** When a supervisor is terminated, it attempts to terminate its children in reverse order of startup. `GenServer`s should implement `terminate/2` to clean up resources (e.g., close files, flush buffers to disk, release ETS tables they own).

**How this Structure Enhances Stability During Failures:**

*   **Debugging Failures:** If a `ElixirScope.Debugger.SessionManager` process for one user's session crashes due to an unexpected condition or a bug related to the state of the target application being debugged, its `:simple_one_for_one` supervisor will terminate it. This crash is isolated to that single session. Other debug sessions, ongoing CPG analysis, or event capture remain unaffected. The user might see an error for their session, but ElixirScope as a whole remains operational.
*   **Analysis Failures:** If a `Task` performing a specific code smell analysis on a module crashes (e.g., due to an edge case in the CPG data or a bug in the analysis algorithm), `Task.Supervisor` handles its termination. The `AnalysisOrchestrator` that `await`ed this task would receive an error for that specific analysis type/module but can continue processing other results or report a partial success. The rest of ElixirScope, including the Foundation layer services, is untouched.
*   **Foundation Service Failures:** Even if a core service like `EventStore` crashes, the `ElixirScope.Foundation.Supervisor` restarts it. During the brief downtime:
    *   The `Capture` layer's `EventCollector`s might see their `EventStore.store_batch` calls fail or timeout. They should have retry logic or temporary buffering to handle this.
    *   Other parts of the system might not be able to query past events, but core functionality like new event capture (buffered upstream) or configuration access can continue. Once `EventStore` restarts (potentially recovering its state from disk or a snapshot), normal operation resumes.

This layered and granular supervision approach is fundamental to OTP's philosophy and is how ElixirScope can achieve the high degree of resilience required for a robust developer tool.