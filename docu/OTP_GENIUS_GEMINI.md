"You are a principal Elixir/OTP engineer with deep expertise in the BEAM's concurrency model, fault tolerance, and distributed systems. You are tasked with writing the 'Concurrency Architecture and Best Practices' section of the ElixirScope technical documentation. Your audience is other senior Elixir developers who will be contributing to or extending ElixirScope. Your explanations should be precise, leverage correct BEAM/OTP terminology, and provide ElixirScope-specific examples where possible."

Based on the provided ElixirScope `README.md`, `CURSOR_TESTS_FOUNDATION.md`, and `FOUNDATION_GRAPH_01.ex` (partial):

Provide a detailed explanation of the concurrency model in the BEAM virtual machine and OTP framework, emphasizing how it supports high concurrency and fault tolerance in Elixir applications like ElixirScope. Include discussions on lightweight processes, schedulers, the actor model, and how BEAM’s scheduler manages process execution to benefit applications requiring multiple concurrent tasks, such as ElixirScope’s runtime event capture and debugging.

Write the introductory section for "BEAM/OTP Concurrency in ElixirScope." This section should:

1.  **Briefly recap core BEAM concurrency primitives relevant to ElixirScope:**
    *   Lightweight, isolated processes.
    *   Asynchronous message passing (send/receive).
    *   The role of schedulers and pre-emptive multitasking.
    *   Immutable data structures and their impact on concurrency.
2.  **Introduce key OTP Behaviours critical for ElixirScope's architecture:**
    *   `GenServer`: For stateful services, background tasks, and managing resources. (Mention `ConfigServer`, `EventStore`, `TelemetryService` from the Foundation layer as prime examples).
    *   `Supervisor`: For fault tolerance, process monitoring, and restart strategies. Explain how this is fundamental for a robust platform like ElixirScope.
    *   `Application`: For structuring the overall system and managing lifecycles.
    *   `Task` & `Task.Supervisor`: For concurrent, often short-lived computations (e.g., parallelizing parts of analysis, AI calls).
    *   `Agent`: For simple shared state (if applicable, though `GenServer` is often preferred for more complex logic).
3.  **Explain why these BEAM/OTP features are particularly well-suited for ElixirScope's goals**, such as:
    *   Handling concurrent user interactions (e.g., multiple debug sessions, live intelligence queries).
    *   Processing large amounts of data (ASTs, CPGs, runtime events) efficiently.
    *   Integrating with external services (like LLMs) without blocking core operations.
    *   Ensuring high availability and resilience for a debugging/analysis platform.
4.  Provide a high-level statement on ElixirScope's philosophy towards concurrency: e.g., "ElixirScope leverages the BEAM's concurrency model extensively to achieve responsiveness, scalability, and fault tolerance across its 9-layer architecture. Each layer is designed with concurrency in mind, utilizing appropriate OTP behaviours and patterns to manage state, perform work in parallel, and handle asynchronous operations."

Focus on setting the stage for more detailed layer-specific discussions.
```

---

**Prompt 2: Concurrency in the Foundation Layer**

```prompt
**Subject: ElixirScope Concurrency - Foundation Layer Deep Dive**

Referencing the ElixirScope `README.md`, `CURSOR_TESTS_FOUNDATION.md`, and the provided `FOUNDATION_GRAPH_01.ex` snippet:

Detail the concurrency model and OTP usage within the **Foundation Layer** of ElixirScope. Specifically address:

1.  **`ElixirScope.Foundation.Services.ConfigServer`**:
    *   Explain its role as a `GenServer`.
    *   How does it handle concurrent read requests (e.g., `get/0`, `get/1`)? Are these typically `GenServer.call/2`?
    *   How does it handle concurrent write/update requests (e.g., `update/2`)? How is state consistency maintained?
    *   Discuss potential bottlenecks if many parts of the system frequently query or update configuration.
    *   How are subscriptions (`subscribe/0`) handled concurrently? What OTP patterns (e.g., `Registry`, `pg`) might be used or considered for broadcasting updates?
    *   Address the "Concurrent Config Updates" concern from `CURSOR_TESTS_FOUNDATION.md`.
2.  **`ElixirScope.Foundation.Services.EventStore` (assume this is a GenServer or uses one):**
    *   Explain its role in managing events.
    *   How does it handle concurrent event submissions (`store/1`)? Are events batched?
    *   How does it handle concurrent event queries?
    *   Discuss strategies for preventing the EventStore from becoming a bottleneck, especially if the `Capture` layer generates many events.
    *   Address the "Event Store Race Conditions" and "Massive Event Data" concerns from `CURSOR_TESTS_FOUNDATION.md`. How can OTP help (e.g., message queueing, backpressure considerations for producers)?
3.  **`ElixirScope.Foundation.Services.TelemetryService` (assume this is a GenServer or uses one):**
    *   Explain its role in metrics collection.
    *   How does it handle high-frequency metric submissions from various parts of ElixirScope?
    *   Discuss aggregation strategies within the GenServer or using `:telemetry` handlers to avoid overwhelming the service.
    *   Address the "Telemetry Service Contention" concern from `CURSOR_TESTS_FOUNDATION.md`.
4.  **Utils like `ElixirScope.Foundation.Utils.generate_id/0`:**
    *   If ID generation needs to be globally unique and race-condition-free across the system, discuss patterns (e.g., a dedicated `GenServer` for ID generation, or strategies if using distributed IDs). Address the "ID Generation Collisions" concern from `CURSOR_TESTS_FOUNDATION.md`.
5.  **Supervision Strategy within the Foundation Layer:**
    *   How are these core services supervised? (Likely by `ElixirScope.Foundation.Application`).
    *   What are appropriate restart strategies for these critical services?
    *   How does the Foundation layer ensure robustness and graceful degradation, as mentioned in `CURSOR_TESTS_FOUNDATION.md`?

Provide Elixir-specific examples of `GenServer` calls, message handling, or supervision setup relevant to this layer.
```

---

**Prompt 3: Concurrency Across AST, Graph, CPG, and Analysis Layers**

```prompt
**Subject: ElixirScope Concurrency - Code Analysis Pipeline (AST, Graph, CPG, Analysis)**

Referencing the ElixirScope `README.md`:

Describe how BEAM/OTP concurrency patterns are (or should be) utilized across the **AST, Graph, CPG, and Analysis layers** to achieve performance and scalability. Consider:

1.  **AST Layer (Parsing & Repository):**
    *   **Parallel Parsing:** How can ElixirScope parse multiple Elixir files or modules concurrently (e.g., `Task.async_stream/3` over a list of files)?
    *   **AST Repository Management:** If the AST repository is a central service (e.g., a `GenServer` or ETS-backed store), how is concurrent access (reads/writes) managed? Discuss trade-offs of ETS vs. GenServer for this.
2.  **Graph Layer (Algorithms):**
    *   Can graph algorithms (centrality, pathfinding) be parallelized for large graphs? Discuss potential uses of `Task.async/await` for independent sub-computations or parallel traversals if applicable.
3.  **CPG Layer (Construction):**
    *   How can the construction of CFG, DFG, Call Graph, etc., for different modules or parts of the codebase be done in parallel?
    *   If CPG construction involves multiple stages, can these stages be pipelined using processes?
4.  **Analysis Layer (Architectural Analysis, Patterns):**
    *   How can different analysis tasks (e.g., detecting smells, calculating metrics, generating recommendations for different modules/subsystems) be run concurrently?
    *   If an analysis task is long-running, how can it be managed as a background process (e.g., `Task` started by a `GenServer`)?
5.  **Data Flow and Dependencies:**
    *   How is data passed between these layers in a concurrent pipeline? (e.g., message passing, shared ETS tables with ownership semantics, dedicated processes managing intermediate results).
    *   How are dependencies managed if, for example, CPG construction for module B depends on the AST of module A?
6.  **Error Handling and Fault Tolerance:**
    *   How should errors in one part of the analysis pipeline (e.g., parsing a single malformed file) affect the overall process? How can Supervisors and process linking help isolate failures?

Provide conceptual examples or pseudo-code snippets illustrating these concurrent patterns (e.g., using `Task.async_stream` for parsing, `GenServer` for a CPG builder orchestrator).
```

---

**Prompt 4: Concurrency in Capture, Query, Intelligence, and Debugger Layers**

```prompt
**Subject: ElixirScope Concurrency - Runtime Interaction & Advanced Features**

Referencing the ElixirScope `README.md`:

Discuss the concurrency considerations and OTP patterns for the **Capture, Query, Intelligence, and Debugger layers**.

1.  **Capture Layer (Runtime Correlation & Querying):**
    *   **Instrumentation:** How can ElixirScope instrument running applications to capture events (e.g., from Phoenix, Ecto, GenServers) without introducing significant overhead or becoming a bottleneck? Discuss strategies like asynchronous event dispatch, batching, and sampling.
    *   **Event Correlation:** If correlation is complex, how can it be offloaded to background processes or a pool of worker `Task`s?
    *   **Storage:** How do captured events flow concurrently to the `EventStore` in the Foundation layer? What about backpressure mechanisms if the capture rate exceeds storage capacity?
    *   Address the "Runtime Correlation" feature – how are concurrent events from the target application processed and linked to static analysis data?
2.  **Query Layer (Advanced Querying):**
    *   How can the query engine execute complex queries concurrently, especially if they involve joining data from static analysis (CPG) and runtime capture?
    *   Can sub-queries or parts of a query plan be executed in parallel using `Task`s?
3.  **Intelligence Layer (AI/ML Integration):**
    *   **LLM Calls:** API calls to LLMs (OpenAI, Anthropic) are I/O-bound. How should ElixirScope manage concurrent requests to these external services (e.g., using a pool of `Task`s, a `GenServer` managing a queue of requests with concurrency limits)?
    *   **Feature Extraction/Model Inference (if local models are used):** How can these potentially CPU-intensive tasks be parallelized or managed by dedicated worker processes to avoid blocking other operations?
    *   Address the "AI-Powered Analysis" and "AI Debugging Assistance" features – how is concurrency managed when multiple users or automated processes request AI insights?
4.  **Debugger Layer (Sessions, Breakpoints, Time Travel):**
    *   **Multiple Debug Sessions:** How is each debug session managed? Is each session its own process or group of processes (e.g., a `GenServer` per session)?
    *   **Event Handling during Debugging:** How are runtime events captured and processed for a specific debug session concurrently with the application's execution?
    *   **Time-Travel Debugging:** This implies capturing and storing a significant amount of state. How is this state managed concurrently, and how are queries against historical states handled without blocking live debugging? What are the implications for the "max_history_size"?
    *   **Live Code Intelligence / Real-time analysis as you code:** This implies background processes observing code changes and triggering analysis. How is this managed concurrently with other IDE interactions or ElixirScope features?

Focus on the challenges of managing external interactions, high data volumes, and stateful user sessions using OTP.
```

---

**Prompt 5: Global Concurrency Patterns, Challenges, and Best Practices for ElixirScope**

```prompt
**Subject: ElixirScope Concurrency - System-Wide Patterns, Challenges, and Best Practices**

Drawing from the overall ElixirScope architecture (`README.md`) and identified concurrency concerns (`CURSOR_TESTS_FOUNDATION.md`):

Provide a consolidated discussion on system-wide concurrency patterns, potential challenges, and best practices for developers contributing to ElixirScope.

1.  **Common Concurrency Patterns in ElixirScope:**
    *   **Client-Server:** `GenServer`s providing services (e.g., ConfigServer, AST Repository).
    *   **Work Distribution:** Using `Task.Supervisor` and `Task.async/await` or `Task.async_stream` for parallelizable computations (e.g., file parsing, running multiple analysis checks).
    *   **Pub-Sub:** For broadcasting events or updates (e.g., config changes, new analysis results). Mention potential tools like `Registry` or `Phoenix.PubSub` if applicable, or custom `GenServer`-based solutions.
    *   **Finite State Machines (FSMs):** If any components naturally model as FSMs (e.g., a debug session lifecycle, a complex analysis workflow), discuss how `gen_statem` could be used.
2.  **Key Concurrency Challenges & Mitigation Strategies for ElixirScope:**
    *   **Bottlenecks:** Identifying and mitigating single `GenServer` bottlenecks (e.g., sharding, read replicas, offloading work, careful API design to prefer `cast` over `call` where appropriate).
    *   **Race Conditions:** Strategies for avoiding them, especially with shared resources (ETS tables, external services). Emphasize process ownership and message passing. Refer to specific concerns like "Event Store Race Conditions."
    *   **Deadlocks:** How to design interactions between processes to avoid deadlocks (e.g., consistent lock ordering if using explicit locks, careful use of `GenServer.call` between dependent servers).
    *   **Backpressure:** Mechanisms for services to signal upstream producers when they are overloaded (e.g., for the `Capture` layer feeding the `EventStore`). Discuss GenStage or custom buffer/demand patterns.
    *   **Error Propagation & Fault Isolation:** How Supervisors, linking, and monitoring ensure that failures in one part of the system (e.g., one AI analysis task) don't bring down unrelated parts or entire layers.
    *   **Resource Management:** Address "Memory Leak Detection," "File Descriptor Limits," "Process Limits" from `CURSOR_TESTS_FOUNDATION.md`. How does OTP help, and what custom strategies are needed?
3.  **Concurrency Best Practices for ElixirScope Developers:**
    *   When to choose `Task` vs. `Agent` vs. `GenServer`.
    *   Designing `GenServer` APIs: `call` vs. `cast` vs. `info` messages.
    *   Idempotency in message handlers.
    *   Structuring supervision trees effectively for different parts of ElixirScope.
    *   Testing concurrent code: Mention strategies from `CURSOR_TESTS_FOUNDATION.md` (e.g., "Concurrency & Race Conditions" tests, Chaos & Stress Testing).
    *   Avoiding common pitfalls (e.g., long-running synchronous calls in `GenServer` callbacks, sharing mutable state directly between processes).
4.  **Observability and Debugging Concurrency:**
    *   Mentioning tools like `:observer`, `recon`, and `:telemetry` events emitted by ElixirScope itself for understanding process states, message queues, and overall system health related to concurrency.

This section should serve as a practical guide for ElixirScope developers.
```

---

**Prompt 6: Advanced Topic - Distributed ElixirScope (Optional but good to consider)**

```prompt
**Subject: ElixirScope Concurrency - Considerations for Distributed Operation (Roadmap Item)**

The ElixirScope roadmap (`README.md`) mentions "Distributed system analysis" for v0.3.0 and a "Cloud-based analysis platform" for v0.4.0.

Briefly outline key BEAM/OTP features and concurrency considerations that would become important if ElixirScope were to operate in a distributed environment (multiple BEAM nodes). Discuss:

1.  **Node Connectivity & Discovery:** (e.g., `libcluster`).
2.  **Distributed `GenServer`s / State Management:** How services like `ConfigServer` or `EventStore` might be adapted. (e.g., Horde, Raft-based consensus, CRDTs, or simply federated but independent instances).
3.  **Distributed `Task`s & Work Distribution:** How analysis or capture tasks could be distributed across a cluster.
4.  **Global Registries / PubSub:** Using tools like `Phoenix.PubSub` with a PG2 adapter or `Swarm` for distributed eventing.
5.  **Challenges:** Network partitions (CAP theorem implications), data consistency, distributed tracing.
6.  How ElixirScope's current design (if well-factored around message passing and OTP) facilitates or hinders a move towards distribution.

This is forward-looking, so focus on high-level concepts and BEAM capabilities.
```

By running these prompts (potentially with some iteration and refinement based on the LLM's output), you should be able to generate a comprehensive and technically deep document covering the concurrency aspects of ElixirScope. Remember to feed the relevant parts of the provided context (README, TEST_PLAN, GRAPH_DATA) with each prompt if the LLM doesn't have persistent memory of them.
