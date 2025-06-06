# ElixirScope Foundation Layer - Technical Architecture Diagrams

## 1. Foundation Layer Service Architecture

```mermaid
graph TB
    subgraph "Foundation Layer"
        subgraph "Public APIs"
            Config[Config API]
            Events[Events API]
            Telemetry[Telemetry API]
            Foundation[Foundation API]
        end
        
        subgraph "Service Layer"
            CS[ConfigServer]
            ES[EventStore]
            TS[TelemetryService]
        end
        
        subgraph "Logic Layer"
            CL[ConfigLogic]
            EL[EventLogic]
        end
        
        subgraph "Validation Layer"
            CV[ConfigValidator]
            EV[EventValidator]
        end
        
        subgraph "Types Layer"
            CT[Config Types]
            ET[Event Types]
            ERR[Error Types]
        end
        
        subgraph "Infrastructure"
            PR[ProcessRegistry]
            SR[ServiceRegistry]
            Utils[Utils]
            GD[GracefulDegradation]
        end
        
        subgraph "Contracts"
            CC[Configurable Contract]
            ESC[EventStore Contract]
            TC[Telemetry Contract]
        end
    end
    
    %% API to Service connections
    Config --> CS
    Events --> ES
    Telemetry --> TS
    
    %% Service to Logic connections
    CS --> CL
    ES --> EL
    
    %% Service to Validation connections
    CS --> CV
    ES --> EV
    
    %% Logic to Types connections
    CL --> CT
    EL --> ET
    CL --> ERR
    EL --> ERR
    
    %% Validation to Types connections
    CV --> CT
    CV --> ERR
    EV --> ET
    EV --> ERR
    
    %% Service to Infrastructure connections
    CS --> SR
    ES --> SR
    TS --> SR
    SR --> PR
    
    %% Contract implementations
    CS -.->|implements| CC
    ES -.->|implements| ESC
    TS -.->|implements| TC
    
    %% Graceful degradation
    Config --> GD
    Events --> GD
    
    style Config fill:#e1f5fe,color:black
    style Events fill:#f3e5f5,color:black
    style Telemetry fill:#e8f5e8,color:black
    style Foundation fill:#fff3e0,color:black
```

## 2. OTP Supervision Tree

```mermaid
graph TD
    App[ElixirScope.Application]
    
    App --> Registry[ProcessRegistry]
    App --> CS[ConfigServer]
    App --> ES[EventStore]
    App --> TS[TelemetryService]
    App --> TaskSup[Task.Supervisor]
    
    subgraph "Service Registration"
        Registry --> |via_tuple| CSReg[":config_server"]
        Registry --> |via_tuple| ESReg[":event_store"]
        Registry --> |via_tuple| TSReg[":telemetry_service"]
    end
    
    subgraph "Service Dependencies"
        CS --> |uses| Registry
        ES --> |uses| Registry
        TS --> |uses| Registry
        
        CS --> |emits| TelemetryEvents[Telemetry Events]
        ES --> |emits| TelemetryEvents
        
        CS --> |stores| Events[Events]
        ES --> |provides| Events
    end
    
    subgraph "Supervision Strategy"
        App -.->|one_for_one| RestartPolicy[Restart Individual Services]
    end
    
    style App fill:#ffcdd2,color:black
    style Registry fill:#c8e6c9,color:black
    style CS fill:#bbdefb,color:black
    style ES fill:#d1c4e9,color:black
    style TS fill:#dcedc8,color:black
```

## 3. Service Interaction Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant CA as Config API
    participant CS as ConfigServer
    participant CL as ConfigLogic
    participant CV as ConfigValidator
    participant SR as ServiceRegistry
    participant ES as EventStore
    participant TS as TelemetryService
    
    Note over C,TS: Configuration Update Flow
    
    C->>CA: update([:ai, :provider], :openai)
    CA->>SR: lookup(:production, :config_server)
    SR-->>CA: {:ok, pid}
    CA->>CS: GenServer.call({:update_config, path, value})
    
    CS->>CL: update_config(config, path, value)
    CL->>CV: validate(new_config)
    CV-->>CL: :ok
    CL-->>CS: {:ok, new_config}
    
    CS->>CS: update state
    CS->>CS: notify_subscribers({:config_updated, path, value})
    
    par Telemetry Emission
        CS->>TS: emit_counter([:foundation, :config_updates])
    and Event Storage
        CS->>ES: store(config_event)
    end
    
    CS-->>CA: :ok
    CA-->>C: :ok
```

## 4. Event Processing Pipeline

```mermaid
graph LR
    subgraph "Event Creation"
        EC[Event Creation]
        EL[EventLogic.create_event/3]
        EV[EventValidator.validate/1]
    end
    
    subgraph "Event Storage"
        ES[EventStore.store/1]
        ESImpl[EventStore Implementation]
        ETS[ETS Storage]
    end
    
    subgraph "Event Querying"
        EQ[Event Queries]
        QF[Query Filters]
        QE[Query Executor]
    end
    
    subgraph "Event Serialization"
        Ser[Serialize Event]
        Deser[Deserialize Event]
        GD[Graceful Degradation]
    end
    
    EC --> EL
    EL --> EV
    EV --> ES
    ES --> ESImpl
    ESImpl --> ETS
    
    ETS --> EQ
    EQ --> QF
    QF --> QE
    
    EL --> Ser
    Ser --> GD
    GD --> Deser
    
    style EC fill:#e3f2fd,color:black
    style ES fill:#f3e5f5,color:black
    style EQ fill:#e8f5e8,color:black
    style Ser fill:#fff3e0,color:black
```

## 5. Configuration Management Flow

```mermaid
graph TD
    subgraph "Configuration Sources"
        Default[Default Config]
        Env[Environment Variables]
        Runtime[Runtime Updates]
    end
    
    subgraph "Configuration Processing"
        Builder[Config Builder]
        Merger[Config Merger]
        Validator[Config Validator]
    end
    
    subgraph "Configuration Storage"
        State[GenServer State]
        Cache[Fallback Cache]
    end
    
    subgraph "Configuration Access"
        Get[get/1]
        Update[update/2]
        Subscribe[subscribe/0]
    end
    
    Default --> Builder
    Env --> Merger
    Runtime --> Merger
    Builder --> Merger
    
    Merger --> Validator
    Validator --> State
    State --> Cache
    
    State --> Get
    State --> Update
    State --> Subscribe
    
    Update --> Validator
    Subscribe --> Notification[Subscriber Notification]
    
    subgraph "Updatable Paths"
        UP1["[:ai, :planning, :sampling_rate]"]
        UP2["[:capture, :processing, :batch_size]"]
        UP3["[:dev, :debug_mode]"]
    end
    
    Update -.-> UP1
    Update -.-> UP2
    Update -.-> UP3
    
    style Default fill:#e1f5fe,color:black
    style Validator fill:#ffebee,color:black
    style State fill:#e8f5e8,color:black
```

## 6. Registry Architecture & Performance

```mermaid
graph TB
    subgraph "Registry Layer"
        PR[ProcessRegistry]
        SR[ServiceRegistry]
    end
    
    subgraph "Storage Backends"
        Native[Native Registry]
        ETS[ETS Backup Table]
    end
    
    subgraph "Namespaces"
        Prod[":production"]
        Test["{:test, ref}"]
    end
    
    subgraph "Operations"
        Reg[register/3]
        Look[lookup/2]
        List[list_services/1]
        Stats[stats/0]
    end
    
    subgraph "Performance Characteristics"
        Lookup["O(1) Lookup Time"]
        Memory["~100 bytes per process"]
        Partition["CPU-optimized partitions"]
        Monitor["Automatic cleanup"]
    end
    
    PR --> Native
    PR --> ETS
    SR --> PR
    
    Native --> Prod
    Native --> Test
    ETS --> Prod
    ETS --> Test
    
    SR --> Reg
    SR --> Look
    SR --> List
    SR --> Stats
    
    Look -.-> Lookup
    Reg -.-> Memory
    Native -.-> Partition
    ETS -.-> Monitor
    
    style PR fill:#c8e6c9,color:black
    style SR fill:#bbdefb,color:black
    style Native fill:#dcedc8,color:black
    style ETS fill:#f8bbd9,color:black
```

## 7. Error Handling & Context Propagation

```mermaid
graph TD
    subgraph "Error Types"
        ConfigErr[Config Errors<br/>1001-1999]
        SystemErr[System Errors<br/>2001-2999]
        DataErr[Data Errors<br/>3001-3999]
        ExtErr[External Errors<br/>4001-4999]
    end
    
    subgraph "Error Context"
        EC[ErrorContext]
        Breadcrumbs[Operation Breadcrumbs]
        Correlation[Correlation IDs]
        Recovery[Recovery Actions]
    end
    
    subgraph "Error Propagation"
        Create[Error Creation]
        Enhance[Context Enhancement]
        Chain[Error Chaining]
        Report[Error Reporting]
    end
    
    subgraph "Graceful Degradation"
        Fallback[Fallback Mechanisms]
        Cache[Cached Responses]
        Retry[Retry Strategies]
    end
    
    ConfigErr --> EC
    SystemErr --> EC
    DataErr --> EC
    ExtErr --> EC
    
    EC --> Breadcrumbs
    EC --> Correlation
    EC --> Recovery
    
    EC --> Create
    Create --> Enhance
    Enhance --> Chain
    Chain --> Report
    
    Report --> Fallback
    Report --> Cache
    Report --> Retry
    
    style ConfigErr fill:#ffcdd2,color:black
    style SystemErr fill:#ffab91,color:black
    style DataErr fill:#ce93d8,color:black
    style ExtErr fill:#90caf9,color:black
    style EC fill:#c8e6c9,color:black
```

## 8. Telemetry & Metrics Collection

```mermaid
graph LR
    subgraph "Telemetry Sources"
        ConfigTel[Config Events]
        EventTel[Event Operations]
        RegistryTel[Registry Operations]
        SystemTel[System Metrics]
    end
    
    subgraph "Telemetry Service"
        Handler[Event Handlers]
        Aggregator[Metric Aggregator]
        Storage[Metric Storage]
    end
    
    subgraph "Metric Types"
        Counter[Counters]
        Gauge[Gauges]
        Histogram[Histograms]
        Summary[Summaries]
    end
    
    subgraph "Output Formats"
        Internal[Internal Queries]
        Prometheus[Prometheus Format]
        JSON[JSON Export]
    end
    
    ConfigTel --> Handler
    EventTel --> Handler
    RegistryTel --> Handler
    SystemTel --> Handler
    
    Handler --> Aggregator
    Aggregator --> Storage
    
    Storage --> Counter
    Storage --> Gauge
    Storage --> Histogram
    Storage --> Summary
    
    Counter --> Internal
    Gauge --> Prometheus
    Histogram --> JSON
    
    style ConfigTel fill:#e1f5fe,color:black
    style EventTel fill:#f3e5f5,color:black
    style Handler fill:#e8f5e8,color:black
    style Storage fill:#fff3e0,color:black
```

## 9. Service Lifecycle & Health Monitoring

```mermaid
stateDiagram-v2
    [*] --> Initializing
    
    Initializing --> Running: Successful startup
    Initializing --> Failed: Initialization error
    
    Running --> Degraded: Service unavailable
    Running --> Stopping: Shutdown signal
    
    Degraded --> Running: Service recovered
    Degraded --> Failed: Recovery failed
    
    Stopping --> Stopped: Clean shutdown
    Stopping --> Failed: Shutdown error
    
    Failed --> Initializing: Supervisor restart
    Stopped --> [*]
    
    state Running {
        [*] --> Healthy
        Healthy --> Warning: Performance issues
        Warning --> Healthy: Issues resolved
        Warning --> Critical: Severe problems
        Critical --> Warning: Partial recovery
    }
    
    state Degraded {
        [*] --> CacheFallback
        CacheFallback --> RetryMode
        RetryMode --> CacheFallback
    }
```

## 10. Data Flow & Message Passing

```mermaid
graph TB
    subgraph "Client Layer"
        Client[Client Process]
        API[Public APIs]
    end
    
    subgraph "Service Layer"
        ConfigServer[ConfigServer]
        EventStore[EventStore]
        TelemetryService[TelemetryService]
    end
    
    subgraph "Cross-Cutting Concerns"
        Registry[Service Registry]
        ErrorHandler[Error Handler]
        Telemetry[Telemetry System]
    end
    
    Client --> API
    API --> |GenServer.call| ConfigServer
    API --> |GenServer.call| EventStore
    API --> |GenServer.cast| TelemetryService
    
    ConfigServer --> |notify_subscribers| Subscribers[Subscriber Processes]
    ConfigServer --> |emit_event| EventStore
    ConfigServer --> |emit_telemetry| TelemetryService
    
    EventStore --> |emit_telemetry| TelemetryService
    
    ConfigServer -.-> |register| Registry
    EventStore -.-> |register| Registry
    TelemetryService -.-> |register| Registry
    
    ConfigServer -.-> |on_error| ErrorHandler
    EventStore -.-> |on_error| ErrorHandler
    
    ErrorHandler --> |emit_metrics| Telemetry
    
    style Client fill:#e3f2fd,color:black
    style ConfigServer fill:#bbdefb,color:black
    style EventStore fill:#d1c4e9,color:black
    style TelemetryService fill:#dcedc8,color:black
    style Registry fill:#c8e6c9,color:black
```

## 11. Testing Architecture

```mermaid
graph TD
    subgraph "Test Types"
        Unit[Unit Tests]
        Integration[Integration Tests]
        Property[Property Tests]
        Performance[Performance Tests]
    end
    
    subgraph "Test Infrastructure"
        TestSup[Test Supervisor]
        TestRegistry[Test Registry]
        TestNamespaces[Test Namespaces]
        Cleanup[Test Cleanup]
    end
    
    subgraph "Test Utilities"
        Factory[Test Factory]
        Helpers[Test Helpers]
        Assertions[Custom Assertions]
        Mocks[Mock Services]
    end
    
    subgraph "Test Isolation"
        ProcessIsolation[Process Isolation]
        NamespaceIsolation[Namespace Isolation]
        StateReset[State Reset]
    end
    
    Unit --> TestSup
    Integration --> TestRegistry
    Property --> TestNamespaces
    Performance --> Cleanup
    
    TestSup --> Factory
    TestRegistry --> Helpers
    TestNamespaces --> Assertions
    Cleanup --> Mocks
    
    Factory --> ProcessIsolation
    Helpers --> NamespaceIsolation
    Assertions --> StateReset
    
    style Unit fill:#e8f5e8,color:black
    style Integration fill:#fff3e0,color:black
    style Property fill:#f3e5f5,color:black
    style Performance fill:#e1f5fe,color:black
```

## 12. Configuration Schema & Validation

```mermaid
graph LR
    subgraph "Configuration Schema"
        Root[Config Root]
        AI[AI Config]
        Capture[Capture Config]
        Storage[Storage Config]
        Interface[Interface Config]
        Dev[Dev Config]
    end
    
    subgraph "AI Configuration"
        Provider[Provider Settings]
        Analysis[Analysis Settings]
        Planning[Planning Settings]
    end
    
    subgraph "Capture Configuration"
        RingBuffer[Ring Buffer]
        Processing[Processing]
        VMTracing[VM Tracing]
    end
    
    subgraph "Storage Configuration"
        Hot[Hot Storage]
        Warm[Warm Storage]
        Cold[Cold Storage]
    end
    
    subgraph "Validation Pipeline"
        CV[ConfigValidator]
        TypeCheck[Type Validation]
        RangeCheck[Range Validation]
        ConstraintCheck[Constraint Validation]
        DependencyCheck[Dependency Validation]
    end
    
    subgraph "Validation Flow"
        VF1[validate/1]
        VF2[validate_ai_config/1]
        VF3[validate_capture_config/1]
        VF4[validate_storage_config/1]
        VF5[validate_interface_config/1]
        VF6[validate_dev_config/1]
    end
    
    %% Schema Structure
    Root --> AI
    Root --> Capture
    Root --> Storage
    Root --> Interface
    Root --> Dev
    
    %% AI Configuration Details
    AI --> Provider
    AI --> Analysis
    AI --> Planning
    
    %% Capture Configuration Details
    Capture --> RingBuffer
    Capture --> Processing
    Capture --> VMTracing
    
    %% Storage Configuration Details
    Storage --> Hot
    Storage --> Warm
    Storage --> Cold
    
    %% Validation Pipeline Flow
    CV --> VF1
    VF1 --> VF2
    VF1 --> VF3
    VF1 --> VF4
    VF1 --> VF5
    VF1 --> VF6
    
    %% Validation Rules Applied to Schema Elements
    VF2 --> TypeCheck
    VF2 --> RangeCheck
    Provider -.-> TypeCheck
    Analysis -.-> RangeCheck
    Planning -.-> ConstraintCheck
    
    VF3 --> ConstraintCheck
    VF3 --> DependencyCheck
    RingBuffer -.-> DependencyCheck
    Processing -.-> ConstraintCheck
    VMTracing -.-> TypeCheck
    
    VF4 --> TypeCheck
    VF4 --> DependencyCheck
    Hot -.-> RangeCheck
    Warm -.-> DependencyCheck
    Cold -.-> TypeCheck
    
    VF5 --> TypeCheck
    VF5 --> RangeCheck
    Interface -.-> RangeCheck
    
    VF6 --> TypeCheck
    Dev -.-> TypeCheck
    
    %% Updatable Paths
    subgraph "Runtime Updatable Paths"
        UP1["[:ai, :planning, :sampling_rate]"]
        UP2["[:capture, :processing, :batch_size]"]
        UP3["[:dev, :debug_mode]"]
        UP4["[:interface, :query_timeout]"]
    end
    
    Planning -.-> UP1
    Processing -.-> UP2
    Dev -.-> UP3
    Interface -.-> UP4
    
    style Root fill:#e1f5fe,color:black
    style AI fill:#f3e5f5,color:black
    style Capture fill:#e8f5e8,color:black
    style Storage fill:#fff3e0,color:black
    style CV fill:#ffebee,color:black
    style VF1 fill:#ffcdd2,color:black
    style UP1 fill:#c8e6c9,color:black
    style UP2 fill:#c8e6c9,color:black
    style UP3 fill:#c8e6c9,color:black
    style UP4 fill:#c8e6c9,color:black
```

These diagrams provide a comprehensive technical overview of the Foundation layer's internal architecture, showing:

1. **Service Architecture** - How components are organized and interact
2. **OTP Supervision** - Process supervision and lifecycle management
3. **Service Interactions** - Message flows and communication patterns
4. **Event Processing** - Event creation, storage, and querying pipeline
5. **Configuration Management** - Configuration processing and validation
6. **Registry Performance** - Process registration and discovery architecture
7. **Error Handling** - Error propagation and context management
8. **Telemetry Collection** - Metrics gathering and processing
9. **Service Lifecycle** - State transitions and health monitoring
10. **Data Flow** - Message passing between components
11. **Testing Architecture** - Test infrastructure and isolation
12. **Configuration Schema** - Configuration structure and validation

Each diagram focuses on a specific aspect of the Foundation layer, providing the technical detail needed to understand the implementation and design decisions.
