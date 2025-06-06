### 1. System Architecture Overview

This diagram provides a high-level view of the entire 8-layer ElixirScope architecture, with Foundation as the base layer. It shows the components within each layer and their primary dependencies.

```mermaid
graph TB
    subgraph "ElixirScope Unified Package"
        subgraph "Layer 8: Debugger Interface"
            DEBUG["Debugger Layer"]
            SESSIONS["Session Management"]
            BREAKPOINTS["Breakpoint Manager"]
            TIMETRAVEL["Time Travel Engine"]
            VISUALIZATION["Visualization Engine"]
        end
        
        subgraph "Layer 7: Intelligence/AI"
            INTEL["Intelligence Layer"]
            LLM["LLM Integration"]
            INSIGHTS["Insight Generator"]
            PREDICTIONS["Prediction Engine"]
            ORCHESTRATOR["AI Orchestrator"]
        end
        
        subgraph "Layer 6: Runtime & Query"
            CAPTURE["Capture Layer"]
            QUERY["Query Layer"]
            INSTR["Instrumentation"]
            CORRELATION["Event Correlation"]
            EXECUTOR["Query Executor"]
            DSL["Query DSL"]
        end
        
        subgraph "Layer 5: Analysis"
            ANALYSIS["Analysis Layer"]
            PATTERNS["Pattern Detection"]
            QUALITY["Quality Assessment"]
            METRICS["Metrics Calculation"]
            RECOMMENDATIONS["Recommendations"]
        end
        
        subgraph "Layer 4: Code Property Graph"
            CPG["CPG Layer"]
            BUILDER["CPG Builder"]
            CFG["Control Flow Graph"]
            DFG["Data Flow Graph"]
            CALLGRAPH["Call Graph"]
            SEMANTIC["Semantic Analysis"]
        end
        
        subgraph "Layer 3: Graph Algorithms"
            GRAPH["Graph Layer - libgraph Hybrid"]
            CENTRALITY["Centrality Algorithms"]
            PATHFINDING["Pathfinding"]
            COMMUNITY["Community Detection"]
            CONVERTERS["Data Converters"]
        end
        
        subgraph "Layer 2: AST Operations"
            AST["AST Layer"]
            PARSER["AST Parser"]
            REPOSITORY["AST Repository"]
            MEMORY["Memory Manager"]
            PATTERNS_AST["Pattern Matcher"]
            QUERY_AST["AST Query Engine"]
        end
    end
    
    subgraph "Layer 1: Foundation (External Dependency)"
        FOUNDATION["Foundation Layer"]
        CONFIG["Config Server"]
        EVENTS["Event Store"]
        TELEMETRY["Telemetry Service"]
        REGISTRY["Process Registry"]
        PROTECTION["Infrastructure Protection"]
    end
    
    %% Layer Dependencies (bottom-up)
    FOUNDATION --> AST
    AST --> GRAPH
    GRAPH --> CPG
    CPG --> ANALYSIS
    ANALYSIS --> CAPTURE
    ANALYSIS --> QUERY
    CAPTURE --> INTEL
    QUERY --> INTEL
    INTEL --> DEBUG
    
    %% Cross-layer integrations
    AST -.-> CPG
    CPG -.-> QUERY
    CAPTURE -.-> DEBUG
    ANALYSIS -.-> INTEL
    
    %% Foundation integration (global access)
    CONFIG -.-> AST
    CONFIG -.-> GRAPH
    CONFIG -.-> CPG
    CONFIG -.-> ANALYSIS
    CONFIG -.-> CAPTURE
    CONFIG -.-> QUERY
    CONFIG -.-> INTEL
    CONFIG -.-> DEBUG
    
    TELEMETRY -.-> AST
    TELEMETRY -.-> GRAPH
    TELEMETRY -.-> CPG
    TELEMETRY -.-> ANALYSIS
    TELEMETRY -.-> CAPTURE
    TELEMETRY -.-> QUERY
    TELEMETRY -.-> INTEL
    TELEMETRY -.-> DEBUG
    
    classDef foundation fill:#e1f5fe,color:#000
    classDef ast fill:#f3e5f5,color:#000
    classDef graph fill:#e8f5e8,color:#000
    classDef cpg fill:#fff3e0,color:#000
    classDef analysis fill:#fce4ec,color:#000
    classDef runtime fill:#f1f8e9,color:#000
    classDef intelligence fill:#e3f2fd,color:#000
    classDef debugger fill:#f8f9fa,color:#000
    
    class FOUNDATION,CONFIG,EVENTS,TELEMETRY,REGISTRY,PROTECTION foundation
    class AST,PARSER,REPOSITORY,MEMORY,PATTERNS_AST,QUERY_AST ast
    class GRAPH,CENTRALITY,PATHFINDING,COMMUNITY,CONVERTERS graph
    class CPG,BUILDER,CFG,DFG,CALLGRAPH,SEMANTIC cpg
    class ANALYSIS,PATTERNS,QUALITY,METRICS,RECOMMENDATIONS analysis
    class CAPTURE,QUERY,INSTR,CORRELATION,EXECUTOR,DSL runtime
    class INTEL,LLM,INSIGHTS,PREDICTIONS,ORCHESTRATOR intelligence
    class DEBUG,SESSIONS,BREAKPOINTS,TIMETRAVEL,VISUALIZATION debugger
```

### 2. Data Flow Architecture

This flowchart visualizes how data moves through the ElixirScope system, from input sources through the various processing pipelines to the final output interfaces.

```mermaid
flowchart LR
    subgraph "Input Sources"
        SOURCE["Source Code"]
        RUNTIME_EVENTS["Runtime Events"]
        USER_QUERIES["User Queries"]
        CONFIG_DATA["Configuration"]
    end
    
    subgraph "Processing Pipeline"
        subgraph "Static Analysis"
            PARSE["AST Parsing"]
            STORE["AST Storage"]
            GRAPH_BUILD["Graph Construction"]
            CPG_BUILD["CPG Construction"]
            PATTERN_DETECT["Pattern Detection"]
        end
        
        subgraph "Runtime Analysis"
            INSTRUMENT["Instrumentation"]
            EVENT_CAPTURE["Event Capture"]
            CORRELATE["Runtime Correlation"]
            TEMPORAL["Temporal Analysis"]
        end
        
        subgraph "Query Processing"
            QUERY_PARSE["Query Parsing"]
            QUERY_OPT["Query Optimization"]
            QUERY_EXEC["Query Execution"]
            RESULT_FORMAT["Result Formatting"]
        end
        
        subgraph "Intelligence"
            AI_PROCESS["AI Processing"]
            INSIGHT_GEN["Insight Generation"]
            PREDICT["Prediction Engine"]
            RECOMMEND["Recommendations"]
        end
    end
    
    subgraph "Output Interfaces"
        DEBUG_UI["Debug Interface"]
        REPORTS["Analysis Reports"]
        METRICS["Metrics Dashboard"]
        ALERTS["Smart Alerts"]
    end
    
    %% Static analysis flow
    SOURCE --> PARSE
    PARSE --> STORE
    STORE --> GRAPH_BUILD
    GRAPH_BUILD --> CPG_BUILD
    CPG_BUILD --> PATTERN_DETECT
    
    %% Runtime analysis flow
    RUNTIME_EVENTS --> INSTRUMENT
    INSTRUMENT --> EVENT_CAPTURE
    EVENT_CAPTURE --> CORRELATE
    CORRELATE --> TEMPORAL
    
    %% Query processing flow
    USER_QUERIES --> QUERY_PARSE
    QUERY_PARSE --> QUERY_OPT
    QUERY_OPT --> QUERY_EXEC
    QUERY_EXEC --> RESULT_FORMAT
    
    %% Intelligence flow
    PATTERN_DETECT --> AI_PROCESS
    TEMPORAL --> AI_PROCESS
    RESULT_FORMAT --> AI_PROCESS
    AI_PROCESS --> INSIGHT_GEN
    INSIGHT_GEN --> PREDICT
    PREDICT --> RECOMMEND
    
    %% Output generation
    RECOMMEND --> DEBUG_UI
    RECOMMEND --> REPORTS
    TEMPORAL --> METRICS
    INSIGHT_GEN --> ALERTS
    
    %% Cross-cutting concerns
    CONFIG_DATA --> PARSE
    CONFIG_DATA --> INSTRUMENT
    CONFIG_DATA --> QUERY_PARSE
    CONFIG_DATA --> AI_PROCESS
```

### 3. Foundation Layer API Architecture

This diagram details the internal components of the `Foundation` external dependency, illustrating the relationship between its core services, registries, and support utilities.

```mermaid
graph TD
    subgraph "Foundation Layer (External Dependency)"
        direction LR
        subgraph "Core Services"
            F_Config["Config Server"]
            F_Events["Event Store"]
            F_Telemetry["Telemetry Service"]
        end

        subgraph "Service & Process Management"
            F_ServiceRegistry["Service Registry"]
            F_ProcessRegistry["Process Registry"]
        end

        subgraph "Infrastructure Protection"
            F_InfraFacade["Protection Facade"]
            F_CircuitBreaker["Circuit Breaker"]
            F_RateLimiter["Rate Limiter"]
            F_ConnectionPool["Connection Pooling"]
        end

        subgraph "Support Libraries"
            F_Error["Error Context & Handling"]
            F_Utils["Utilities (IDs, Timestamps)"]
        end
    end

    %% Internal Dependencies
    F_ServiceRegistry -- "Built on" --> F_ProcessRegistry
    F_CircuitBreaker -- "Managed by" --> F_InfraFacade
    F_RateLimiter -- "Managed by" --> F_InfraFacade
    F_ConnectionPool -- "Managed by" --> F_InfraFacade

    %% Cross-cutting Dependencies (dotted lines)
    F_Config -.-> F_Utils
    F_Events -.-> F_Utils
    F_Telemetry -.-> F_Utils
    F_ServiceRegistry -.-> F_Utils
    F_InfraFacade -.-> F_Utils
    
    F_Config -.-> F_Error
    F_Events -.-> F_Error
    F_Telemetry -.-> F_Error
    F_ServiceRegistry -.-> F_Error
    F_InfraFacade -.-> F_Error

    %% Service Registration
    F_Config -- "Registers with" --> F_ServiceRegistry
    F_Events -- "Registers with" --> F_ServiceRegistry
    F_Telemetry -- "Registers with" --> F_ServiceRegistry

    %% Styling
    classDef foundationCore fill:#e1f5fe,color:#000
    classDef foundationMgmt fill:#c5cae9,color:#000
    classDef foundationInfra fill:#ffcdd2,color:#000
    classDef foundationSupport fill:#f0f4c3,color:#000

    class F_Config,F_Events,F_Telemetry foundationCore
    class F_ServiceRegistry,F_ProcessRegistry foundationMgmt
    class F_InfraFacade,F_CircuitBreaker,F_RateLimiter,F_ConnectionPool foundationInfra
    class F_Error,F_Utils foundationSupport
```

### 4. AST Layer Internal Architecture

This diagram breaks down the internal structure of the AST Layer (Layer 2), showing its main functional components, their interactions, and dependencies on the Foundation layer.

```mermaid
graph TD
    subgraph "External Inputs & Consumers"
        direction TB
        subgraph "Input Sources"
            direction LR
            SourceCode["Source Code Files"]
            FS["File System Events"]
        end
        subgraph "Consumer Layers"
            direction LR
            CPG_Layer["CPG Layer (L4)"]
            Analysis_Layer["Analysis Layer (L5)"]
            Query_Layer["Query Layer (L6b)"]
        end
    end

    subgraph "AST Layer (Layer 2)"
        direction TB
        subgraph "Parsing & Synchronization"
            Parser["Parsing (parser.ex)"]
            Sync["Synchronization (synchronization/)"]
        end

        subgraph "Core Storage"
            Repo["Repository (core.ex, enhanced.ex)"]
            MemMan["Memory Manager (memory_manager/)"]
        end

        subgraph "Analysis & Querying"
            PatternMatcher["Pattern Matcher (pattern_matcher/)"]
            QueryEngine["Query Engine (querying/)"]
        end
        
        subgraph "Data & Transformation"
            DataStructs["Data Structures (data/)"]
            Transformer["Code Transformation (transformation/)"]
        end
    end

    subgraph "Foundation Services (Layer 1)"
        direction LR
        F_Config["Foundation.Config"]
        F_Events["Foundation.Events"]
        F_Telemetry["Foundation.Telemetry"]
        F_Registry["Foundation.ProcessRegistry"]
    end

    %% Data Flow within AST Layer
    SourceCode --> Parser
    FS --> Sync
    Parser --> Repo
    Sync --> Repo
    MemMan -- "Manages" --> Repo
    Repo -- "AST Data" --> PatternMatcher
    Repo -- "AST Data" --> QueryEngine
    Repo -- "AST Data" --> Transformer
    DataStructs -- "Used by all components" -.-> Parser
    DataStructs -.-> Repo
    DataStructs -.-> PatternMatcher
    
    %% Integration with Foundation
    Repo -- "Registers via" --> F_Registry
    Parser -- "Emits Telemetry" --> F_Telemetry
    MemMan -- "Emits Telemetry" --> F_Telemetry
    QueryEngine -- "Uses Config" --> F_Config
    Parser -- "Stores Events" --> F_Events

    %% Integration with Upper Layers
    Repo -- "Provides AST for" --> CPG_Layer
    PatternMatcher -- "Provides patterns for" --> Analysis_Layer
    QueryEngine -- "Executes queries for" --> Query_Layer
    
    %% Styling
    classDef ast fill:#f3e5f5,color:#000
    classDef foundation fill:#e1f5fe,color:#000
    classDef consumer fill:#e8f5e8,color:#000
    classDef input fill:#fffde7,color:#000

    class Parser,Sync,Repo,MemMan,PatternMatcher,QueryEngine,DataStructs,Transformer ast
    class F_Config,F_Events,F_Telemetry,F_Registry foundation
    class CPG_Layer,Analysis_Layer,Query_Layer consumer
    class SourceCode,FS input
```

### 5. Graph Layer Hybrid Architecture

This diagram illustrates the hybrid implementation strategy for the Graph Layer (Layer 3), which combines the external `libgraph` library with custom wrappers, algorithms, and integration with the Foundation layer.

```mermaid
graph TD
    subgraph "Consumer Layers"
        CPG["CPG Layer (L4)"]
        Analysis["Analysis Layer (L5)"]
    end

    subgraph "Graph Layer (Layer 3) - Hybrid Approach"
        subgraph "Custom ElixirScope Logic"
            direction LR
            Converters["Converters (converters.ex)"]
            CustomAlgos["Custom Algorithms (algorithms/)"]
        end

        subgraph "Integration & Core Wrappers"
            direction LR
            CoreWrapper["Core libgraph Wrapper (core.ex)"]
            FoundationIntegration["Foundation Integration (foundation_integration.ex)"]
        end
    end

    subgraph "External & Foundation Dependencies"
        direction LR
        Libgraph["libgraph (External Hex.pm Library)"]
        Foundation["Foundation Layer (L1)"]
    end

    %% Flow and Dependencies
    CPG -- "Uses Graph Algorithms" --> CustomAlgos
    Analysis -- "Uses Graph Algorithms" --> CustomAlgos
    CPG -- "Uses Converters" --> Converters
    
    Converters -- "Uses" --> CoreWrapper
    CustomAlgos -- "Uses" --> CoreWrapper
    CustomAlgos -- "Integrates with" --> FoundationIntegration

    CoreWrapper -- "Wraps and uses" --> Libgraph
    FoundationIntegration -- "Calls" --> Foundation

    %% Styling
    classDef graph fill:#e8f5e8,color:#000
    classDef consumer fill:#fff3e0,color:#000
    classDef dependency fill:#e1f5fe,color:#000
    
    class Converters,CustomAlgos,CoreWrapper,FoundationIntegration graph
    class CPG,Analysis consumer
    class Libgraph,Foundation dependency
```

### 6. CPG Layer Construction Architecture (Layer 4)

This diagram shows how the Code Property Graph (CPG) Layer constructs its unified graph. It visualizes the process of taking the AST as input, building individual graphs like the Control Flow Graph (CFG) and Data Flow Graph (DFG), and combining them into a single, semantically-rich CPG.

```mermaid
graph TD
    subgraph "Input & Foundational Layers"
        AST_Repo["AST Repository (L2)"]
        Graph_Algos["Graph Algorithms (L3)"]
    end

    subgraph "CPG Layer (Layer 4)"
        direction LR
        subgraph "Construction Pipeline"
            direction TB
            Builder["CPG Builder"]
            Semantic["Semantic Analysis"]
            Incremental["Incremental Updater"]
        end

        subgraph "Constituent Graphs"
            direction TB
            CFG["Control Flow Graph (CFG)"]
            DFG["Data Flow Graph (DFG)"]
            CallGraph["Call Graph"]
        end
        
        UnifiedCPG["Unified Code Property Graph"]
    end

    subgraph "Consumer Layers"
        Analysis["Analysis Layer (L5)"]
        Query["Query Layer (L6b)"]
    end

    %% Data Flow for CPG Construction
    AST_Repo -- "Provides AST to" --> Builder
    
    Builder -- "Builds" --> CFG
    Builder -- "Builds" --> DFG
    Builder -- "Builds" --> CallGraph
    
    CFG -- "Combined into" --> UnifiedCPG
    DFG -- "Combined into" --> UnifiedCPG
    CallGraph -- "Combined into" --> UnifiedCPG

    Semantic -- "Enriches" --> UnifiedCPG
    Graph_Algos -- "Used for analysis by" --> Semantic
    
    Incremental -- "Updates" --> UnifiedCPG
    AST_Repo -- "Provides change events to" --> Incremental

    %% Output Flow
    UnifiedCPG -- "Provides graph for" --> Analysis
    UnifiedCPG -- "Provides graph for" --> Query

    %% Styling
    classDef cpg fill:#fff3e0,color:#000
    classDef input fill:#f3e5f5,color:#000
    classDef output fill:#fce4ec,color:#000
    
    class Builder,Semantic,Incremental,CFG,DFG,CallGraph,UnifiedCPG cpg
    class AST_Repo,Graph_Algos input
    class Analysis,Query output
```

### 7. Runtime Correlation Sequence Diagram (Layer 6a)

This sequence diagram details the process of correlating a runtime event with its static code context. It shows the interaction between instrumented code, the Capture Layer, the AST Layer, and the Foundation Event Store.

```mermaid
sequenceDiagram
    participant Code as "Instrumented Code"
    participant Capture as "Capture Layer"
    participant AST as "AST Layer"
    participant Foundation as "Foundation.EventStore"

    Code->>Capture: Function call intercepted (e.g., MyModule.foo/2)
    activate Capture
    
    Capture->>Capture: 1. Generate Correlation ID
    Capture->>Capture: 2. Capture runtime args & metadata
    
    Note right of Capture: Create initial runtime event data
    
    Capture->>AST: 3. Request static context for `MyModule.foo/2`
    activate AST
    
    AST-->>AST: Query AST Repository for module/function
    AST-->>Capture: Return AST node details (e.g., file, line, node_id)
    deactivate AST
    
    Capture->>Capture: 4. Correlate runtime data with static context
    
    Note right of Capture: Create enriched event with both runtime<br/>and static information.
    
    Capture->>Foundation: 5. Store correlated event
    activate Foundation
    Foundation-->>Capture: {:ok, event_id}
    deactivate Foundation
    
    Capture-->>Code: Return control to original function
    deactivate Capture
```

### 8. Unified Query System Architecture (Layer 6b)

This diagram illustrates how the unified Query Layer works. It shows the query lifecycle from parsing a DSL string to executing sub-queries against multiple underlying data layers (AST, CPG, Capture) and returning a single, consolidated result.

```mermaid
graph LR
    subgraph "User Input"
        UserQuery["User Query (SQL-like DSL)"]
    end

    subgraph "Query Layer (Layer 6b)"
        direction TB
        subgraph "Query Processing Engine"
            Builder["Query Builder"]
            Optimizer["Query Optimizer"]
            Executor["Query Executor"]
        end
    end

    subgraph "Data Sources (Layers 2, 4, 6a)"
        direction TB
        AST["AST Repository (L2)"]
        CPG["Code Property Graph (L4)"]
        Capture["Runtime Data (L6a)"]
    end
    
    subgraph "Output"
        Results["Unified Results"]
    end

    %% Query Flow
    UserQuery --> Builder
    Builder -- "Creates Query Plan" --> Optimizer
    Optimizer -- "Provides Execution Plan" --> Executor

    Executor -- "Dispatches AST sub-query" --> AST
    Executor -- "Dispatches CPG sub-query" --> CPG
    Executor -- "Dispatches Runtime sub-query" --> Capture
    
    AST -- "Returns static data" --> Executor
    CPG -- "Returns semantic data" --> Executor
    Capture -- "Returns runtime metrics" --> Executor

    Executor -- "Joins & Formats" --> Results

    %% Styling
    classDef query fill:#f1f8e9,color:#000
    classDef data_source fill:#e3f2fd,color:#000
    classDef user fill:#f8f9fa,color:#000
    classDef output fill:#e8f5e8,color:#000

    class Builder,Optimizer,Executor query
    class AST,CPG,Capture data_source
    class UserQuery user
    class Results output
```

### 9. AI Orchestration Architecture (Layer 7)

This diagram visualizes the AI/Intelligence Layer, showing how the AI Orchestrator gathers data from multiple lower layers, uses it to construct a prompt for an LLM, and then processes the response to generate insights and predictions.

```mermaid
graph TD
    subgraph "Lower Layers (Data Sources)"
        AST_Data["AST Layer (L2)<br/><i>Code Structure</i>"]
        CPG_Data["CPG Layer (L4)<br/><i>Semantic Relationships</i>"]
        Analysis_Data["Analysis Layer (L5)<br/><i>Detected Patterns</i>"]
        Capture_Data["Capture Layer (L6a)<br/><i>Runtime Behavior</i>"]
    end
    
    subgraph "Intelligence Layer (L7)"
        Orchestrator["AI Orchestrator"]
        LLM_Integration["LLM Integration<br/><i>(OpenAI, Gemini, etc.)</i>"]
        
        subgraph "AI-Powered Output Generation"
            Insight_Gen["Insight Generator"]
            Prediction_Engine["Prediction Engine"]
        end
    end
    
    subgraph "External Services"
        External_LLM["External LLM Provider"]
    end
    
    subgraph "Final Output"
        Insights["Code Insights & Explanations"]
        Predictions["Refactoring Predictions"]
        Recommendations["Optimization Suggestions"]
    end

    %% Data Flow
    AST_Data -- "Provides Features" --> Orchestrator
    CPG_Data -- "Provides Features" --> Orchestrator
    Analysis_Data -- "Provides Features" --> Orchestrator
    Capture_Data -- "Provides Features" --> Orchestrator
    
    Orchestrator -- "Constructs Prompt & Context" --> LLM_Integration
    LLM_Integration -- "Sends API Request" --> External_LLM
    External_LLM -- "Returns AI Response" --> LLM_Integration
    
    LLM_Integration -- "Provides Raw AI Output" --> Insight_Gen
    LLM_Integration -- "Provides Raw AI Output" --> Prediction_Engine
    
    Insight_Gen --> Insights
    Prediction_Engine --> Predictions
    Prediction_Engine --> Recommendations
    
    %% Styling
    classDef intelligence fill:#e3f2fd,color:#000
    classDef data_source fill:#f3e5f5,color:#000
    classDef output fill:#e8f5e8,color:#000
    classDef external fill:#fff3e0,color:#000
    
    class Orchestrator,LLM_Integration,Insight_Gen,Prediction_Engine intelligence
    class AST_Data,CPG_Data,Analysis_Data,Capture_Data data_source
    class Insights,Predictions,Recommendations output
    class External_LLM external
```

### 10. Time-Travel Debugging Sequence Diagram (Layer 8)

This sequence diagram illustrates the workflow for a time-travel debugging session. It shows how the Debugger Layer components interact with the Capture and AST layers to reconstruct and present a historical execution state to the user.

```mermaid
sequenceDiagram
    participant UI as "User / Debugger UI"
    participant Debugger as "Debugger Layer"
    participant Capture as "Capture Layer (Temporal Store)"
    participant AST as "AST Layer (Repository)"

    UI->>Debugger: 1. Create Session (correlation_id)
    activate Debugger
    Debugger->>Debugger: SessionManager creates new session
    Debugger-->>UI: {:ok, session}
    
    UI->>Debugger: 2. Go to timestamp `T`
    
    Debugger->>Capture: 3. Get execution timeline around `T`
    activate Capture
    Capture-->>Debugger: Return events and state snapshots
    deactivate Capture
    
    Debugger->>Debugger: TimeTravelEngine identifies target event
    
    Debugger->>AST: 4. Get static code context for event
    activate AST
    AST-->>Debugger: Return file, line, AST node
    deactivate AST
    
    Debugger->>Debugger: 5. Reconstruct historical state
    
    Note right of Debugger: Combine runtime state from Capture<br/>with static code from AST.
    
    Debugger->>Debugger: 6. (Optional) AIAssistant analyzes context
    Debugger-->>UI: 7. Present historical state & AI suggestions
    deactivate Debugger
```

### 11. Implementation Timeline Gantt Chart

This Gantt chart visualizes the 16-week implementation plan described in the documentation, breaking it down by phase and key deliverables.

```mermaid
gantt
    title ElixirScope Implementation Timeline
    dateFormat W
    axisFormat %W
    
    section Phase 1: Foundation (Week 1)
    Foundation Integration     :done, W1, 1w
    Project & Test Setup       :done, W1, 1w
    
    section Phase 2: Core Infrastructure (Weeks 2-6)
    Graph Layer (Hybrid)       :active, W2, 1w
    AST Layer (Core)           :W3, 2w
    CPG Layer (Core)           :W5, 2w
    
    section Phase 3: Analysis & Processing (Weeks 7-10)
    Analysis Layer             :W7, 2w
    Capture Layer              :W8, 2w
    Query Layer                :W10, 1w

    section Phase 4: Intelligence & UI (Weeks 11-14)
    Intelligence Layer (AI/ML) :W11, 2w
    Debugger Layer             :W13, 2w
    
    section Phase 5: Polish & Release (Weeks 15-16)
    End-to-End Testing         :W15, 1w
    Performance & Polish       :W15, 2w
    Documentation & Release    :W16, 1w
```
