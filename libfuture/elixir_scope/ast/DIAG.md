# ElixirScope AST Layer Architecture Diagrams

## 1. AST Layer Component Architecture

```mermaid
graph LR
    subgraph "AST Layer (Layer 2)"
        Parser[Parser]
        Repository[Repository]
        Enhanced[Enhanced Repository]
        MemMgr[Memory Manager]
        PerfOpt[Performance Optimizer]
        PatMat[Pattern Matcher]
        QueryBld[Query Builder]
        Compiler[Compiler/Transformer]
        CompileTime[Compile-Time Orchestrator]
    end

    subgraph "Repository Components"
        Core[Core Repository]
        EnhCore[Enhanced Core]
        ProjectPop[Project Populator]
        Sync[Synchronizer]
        FileWatch[File Watcher]
    end

    subgraph "Data Structures"
        ModData[Module Data]
        FuncData[Function Data]
        ComplexMetrics[Complexity Metrics]
        EnhModData[Enhanced Module Data]
        EnhFuncData[Enhanced Function Data]
        VarData[Variable Data]
        SharedData[Shared Data Structures]
    end

    subgraph "Memory Management"
        Monitor[Memory Monitor]
        Cleaner[Data Cleaner]
        Compressor[Data Compressor]
        CacheMgr[Cache Manager]
        PressureHandler[Pressure Handler]
    end

    subgraph "Pattern Analysis"
        Analyzers[Pattern Analyzers]
        Rules[Pattern Rules]
        Library[Pattern Library]
        Validators[Pattern Validators]
        Stats[Pattern Stats]
        Cache[Pattern Cache]
    end

    Parser --> Repository
    Repository --> Enhanced
    Repository --> Core
    Core --> EnhCore
    Enhanced --> ProjectPop
    Enhanced --> Sync
    Enhanced --> FileWatch
    
    Repository --> ModData
    Repository --> FuncData
    Enhanced --> EnhModData
    Enhanced --> EnhFuncData
    
    MemMgr --> Monitor
    MemMgr --> Cleaner
    MemMgr --> Compressor
    MemMgr --> CacheMgr
    MemMgr --> PressureHandler
    
    PatMat --> Analyzers
    PatMat --> Rules
    PatMat --> Library
    PatMat --> Validators
    PatMat --> Stats
    PatMat --> Cache
    
    QueryBld --> Repository
    PerfOpt --> MemMgr
    Compiler --> Parser
    CompileTime --> Compiler
```

## 2. OTP Supervision Tree

```mermaid
graph LR
    subgraph "AST Layer Supervisor"
        ASTSup[AST.Supervisor]
    end

    subgraph "Core Services"
        RepSup[Repository.Supervisor]
        MemSup[MemoryManager.Supervisor]
        PatSup[PatternMatcher.Supervisor]
        QuerySup[QueryBuilder.Supervisor]
        PerfSup[PerformanceOptimizer.Supervisor]
    end

    subgraph "Repository Processes"
        CoreRepo[Repository.Core]
        EnhRepo[Repository.Enhanced]
        ProjectPop[ProjectPopulator]
        FileSyn[Synchronizer]
        FileWatch[FileWatcher]
    end

    subgraph "Memory Management Processes"
        MemMgr[MemoryManager]
        Monitor[Monitor]
        CacheMgr[CacheManager]
    end

    subgraph "Pattern Matching Processes"
        PatMat[PatternMatcher]
        PatCache[PatternCache]
    end

    subgraph "Query Processes"
        QueryBld[QueryBuilder]
        QueryCache[QueryCache]
        QueryExec[QueryExecutor]
    end

    subgraph "Performance Processes"
        PerfOpt[PerformanceOptimizer]
        BatchProc[BatchProcessor]
        LazyLoader[LazyLoader]
        OptSched[OptimizationScheduler]
        StatsCol[StatisticsCollector]
    end

    ASTSup --> RepSup
    ASTSup --> MemSup
    ASTSup --> PatSup
    ASTSup --> QuerySup
    ASTSup --> PerfSup

    RepSup --> CoreRepo
    RepSup --> EnhRepo
    RepSup --> ProjectPop
    RepSup --> FileSyn
    RepSup --> FileWatch

    MemSup --> MemMgr
    MemSup --> Monitor
    MemSup --> CacheMgr

    PatSup --> PatMat
    PatSup --> PatCache

    QuerySup --> QueryBld
    QuerySup --> QueryCache
    QuerySup --> QueryExec

    PerfSup --> PerfOpt
    PerfSup --> BatchProc
    PerfSup --> LazyLoader
    PerfSup --> OptSched
    PerfSup --> StatsCol

    classDef supervisor fill:#e1f5fe,color:#000
    classDef genserver fill:#f3e5f5,color:#000
    classDef worker fill:#e8f5e8,color:#000

    class ASTSup,RepSup,MemSup,PatSup,QuerySup,PerfSup supervisor
    class CoreRepo,EnhRepo,PatMat,QueryBld,MemMgr,PerfOpt genserver
    class ProjectPop,FileSyn,FileWatch,Monitor,CacheMgr,PatCache,QueryCache,QueryExec,BatchProc,LazyLoader,OptSched,StatsCol worker
```

## 3. Data Flow Architecture

```mermaid
graph LR
    subgraph "Input Sources"
        Source[Source Code]
        Files[File Changes]
        Runtime[Runtime Events]
    end

    subgraph "Parsing Layer"
        Parser[AST Parser]
        InstMap[Instrumentation Mapper]
    end

    subgraph "Storage Layer"
        CoreRepo[Core Repository]
        EnhRepo[Enhanced Repository]
        MemMgr[Memory Manager]
    end

    subgraph "Processing Layer"
        PatMat[Pattern Matcher]
        PerfOpt[Performance Optimizer]
        QueryEng[Query Engine]
    end

    subgraph "Output Interfaces"
        Queries[Query Results]
        Patterns[Pattern Matches]
        Metrics[Performance Metrics]
        Events[Correlated Events]
    end

    subgraph "ETS Tables"
        ModTable[(modules_table)]
        FuncTable[(functions_table)]
        ASTTable[(ast_nodes_table)]
        CorrTable[(correlation_index)]
        CacheTable[(query_cache)]
        PatTable[(pattern_cache)]
    end

    Source --> Parser
    Files --> Parser
    Parser --> InstMap
    InstMap --> CoreRepo
    CoreRepo --> EnhRepo
    EnhRepo --> MemMgr

    CoreRepo --> ModTable
    CoreRepo --> FuncTable
    CoreRepo --> ASTTable
    CoreRepo --> CorrTable

    EnhRepo --> PatMat
    EnhRepo --> PerfOpt
    EnhRepo --> QueryEng

    QueryEng --> CacheTable
    PatMat --> PatTable

    PatMat --> Patterns
    QueryEng --> Queries
    PerfOpt --> Metrics
    Runtime --> Events

    classDef input fill:#fff3e0,color:#000
    classDef process fill:#e3f2fd,color:#000
    classDef storage fill:#f1f8e9,color:#000
    classDef output fill:#fce4ec,color:#000
    classDef ets fill:#fff8e1,color:#000

    class Source,Files,Runtime input
    class Parser,InstMap,PatMat,PerfOpt,QueryEng process
    class CoreRepo,EnhRepo,MemMgr storage
    class Queries,Patterns,Metrics,Events output
    class ModTable,FuncTable,ASTTable,CorrTable,CacheTable,PatTable ets
```

## 4. Memory Management Architecture

```mermaid
graph LR
    subgraph "Memory Manager System"
        MemMgr[Memory Manager]
        Monitor[Memory Monitor]
        Cleaner[Data Cleaner]
        Compressor[Data Compressor]
        CacheMgr[Cache Manager]
        PressHandler[Pressure Handler]
    end

    subgraph "Memory Monitoring"
        MonitorProc[Monitor Process]
        MemStats[Memory Statistics]
        Thresholds[Pressure Thresholds]
        Alerts[Alert System]
    end

    subgraph "Cache Management"
        QueryCache[Query Cache]
        AnalysisCache[Analysis Cache]
        CPGCache[CPG Cache]
        LRUEvict[LRU Eviction]
        TTLClean[TTL Cleanup]
    end

    subgraph "Data Lifecycle"
        AccessTrack[Access Tracking]
        AgeTrack[Age Tracking]
        CompressDecision[Compression Decision]
        CleanupDecision[Cleanup Decision]
    end

    subgraph "Pressure Response"
        Level1[Level 1: Clear Query Cache]
        Level2[Level 2: Compress Old Data]
        Level3[Level 3: Remove Unused Data]
        Level4[Level 4: Emergency GC]
    end

    MemMgr --> Monitor
    MemMgr --> Cleaner
    MemMgr --> Compressor
    MemMgr --> CacheMgr
    MemMgr --> PressHandler

    Monitor --> MonitorProc
    Monitor --> MemStats
    Monitor --> Thresholds
    Monitor --> Alerts

    CacheMgr --> QueryCache
    CacheMgr --> AnalysisCache
    CacheMgr --> CPGCache
    CacheMgr --> LRUEvict
    CacheMgr --> TTLClean

    Cleaner --> AccessTrack
    Cleaner --> AgeTrack
    Compressor --> CompressDecision
    Cleaner --> CleanupDecision

    PressHandler --> Level1
    PressHandler --> Level2
    PressHandler --> Level3
    PressHandler --> Level4

    MemStats --> PressHandler
    AccessTrack --> CompressDecision
    AgeTrack --> CleanupDecision
```

## 5. Pattern Matching Architecture

```mermaid
graph TB
    subgraph "Pattern Matcher System"
        PatMat[Pattern Matcher]
        Core[Pattern Core]
        Analyzers[Pattern Analyzers]
        Library[Pattern Library]
        Cache[Pattern Cache]
    end

    subgraph "Pattern Types"
        ASTPat[AST Patterns]
        BehavPat[Behavioral Patterns]
        AntiPat[Anti-Patterns]
        CustomPat[Custom Patterns]
    end

    subgraph "Pattern Rules"
        GenServer[GenServer Rules]
        Supervisor[Supervisor Rules]
        Phoenix[Phoenix Rules]
        Security[Security Rules]
        Performance[Performance Rules]
    end

    subgraph "Analysis Pipeline"
        Input[Function/Module Data]
        Validation[Pattern Validation]
        Matching[Pattern Matching]
        Confidence[Confidence Calculation]
        Results[Pattern Results]
    end

    subgraph "Caching Strategy"
        CacheKey[Cache Key Generation]
        CacheGet[Cache Lookup]
        CachePut[Cache Storage]
        CacheEvict[Cache Eviction]
    end

    PatMat --> Core
    PatMat --> Analyzers
    PatMat --> Library
    PatMat --> Cache

    Library --> ASTPat
    Library --> BehavPat
    Library --> AntiPat
    Library --> CustomPat

    BehavPat --> GenServer
    BehavPat --> Supervisor
    BehavPat --> Phoenix
    AntiPat --> Security
    AntiPat --> Performance

    Input --> Validation
    Validation --> Matching
    Matching --> Confidence
    Confidence --> Results

    Core --> CacheKey
    CacheKey --> CacheGet
    CacheGet --> CachePut
    CachePut --> CacheEvict

    Analyzers --> Input
    Cache --> CacheGet
    Results --> CachePut
```

## 6. Query Engine Architecture

```mermaid
graph TB
    subgraph "Query Builder System"
        QueryBld[Query Builder]
        Normalizer[Query Normalizer]
        Validator[Query Validator]
        Optimizer[Query Optimizer]
        Executor[Query Executor]
        Cache[Query Cache]
    end

    subgraph "Query Types"
        FuncQuery[Function Queries]
        ModQuery[Module Queries]
        PatQuery[Pattern Queries]
        ComplexQuery[Complex Queries]
    end

    subgraph "Query Processing"
        Parse[Query Parsing]
        Validate[Validation]
        Optimize[Optimization]
        Execute[Execution]
        Cache[Result Caching]
    end

    subgraph "Optimization Strategies"
        IndexUse[Index Usage]
        FilterOrder[Filter Ordering]
        EarlyTerm[Early Termination]
        CacheHits[Cache Hits]
    end

    subgraph "Execution Engine"
        ETSQueries[ETS Queries]
        FilterChain[Filter Chain]
        Sorting[Result Sorting]
        Pagination[Result Pagination]
    end

    QueryBld --> Normalizer
    QueryBld --> Validator
    QueryBld --> Optimizer
    QueryBld --> Executor
    QueryBld --> Cache

    Normalizer --> FuncQuery
    Normalizer --> ModQuery
    Normalizer --> PatQuery
    Normalizer --> ComplexQuery

    Parse --> Validate
    Validate --> Optimize
    Optimize --> Execute
    Execute --> Cache

    Optimizer --> IndexUse
    Optimizer --> FilterOrder
    Optimizer --> EarlyTerm
    Optimizer --> CacheHits

    Executor --> ETSQueries
    Executor --> FilterChain
    Executor --> Sorting
    Executor --> Pagination
```

## 7. Performance Optimization Architecture

```mermaid
graph LR
    subgraph "Performance Optimizer System"
        PerfOpt[Performance Optimizer]
        BatchProc[Batch Processor]
        LazyLoader[Lazy Loader]
        CacheMgr[Cache Manager]
        OptSched[Optimization Scheduler]
        StatsCol[Statistics Collector]
    end

    subgraph "Batch Processing"
        BatchQueue[Batch Queue]
        BatchSize[Batch Sizing]
        ParallelProc[Parallel Processing]
        BatchResults[Batch Results]
    end

    subgraph "Lazy Loading"
        LazyTrigger[Lazy Triggers]
        LoadThreshold[Load Thresholds]
        AccessPattern[Access Patterns]
        LazyCache[Lazy Cache]
    end

    subgraph "Cache Optimization"
        CacheWarm[Cache Warming]
        CacheEvict[Cache Eviction]
        CacheHit[Hit Rate Optimization]
        CacheStats[Cache Statistics]
    end

    subgraph "Scheduling"
        OptCycle[Optimization Cycles]
        MemCleanup[Memory Cleanup]
        ETSOpt[ETS Optimization]
        PerfMetrics[Performance Metrics]
    end

    PerfOpt --> BatchProc
    PerfOpt --> LazyLoader
    PerfOpt --> CacheMgr
    PerfOpt --> OptSched
    PerfOpt --> StatsCol

    BatchProc --> BatchQueue
    BatchProc --> BatchSize
    BatchProc --> ParallelProc
    BatchProc --> BatchResults

    LazyLoader --> LazyTrigger
    LazyLoader --> LoadThreshold
    LazyLoader --> AccessPattern
    LazyLoader --> LazyCache

    CacheMgr --> CacheWarm
    CacheMgr --> CacheEvict
    CacheMgr --> CacheHit
    CacheMgr --> CacheStats

    OptSched --> OptCycle
    OptSched --> MemCleanup
    OptSched --> ETSOpt
    OptSched --> PerfMetrics
```

## 8. File Synchronization Architecture

```mermaid
graph TB
    subgraph "File Synchronization System"
        FileWatch[File Watcher]
        Synchronizer[Synchronizer]
        ProjectPop[Project Populator]
    end

    subgraph "File Watching"
        FSEvents[File System Events]
        EventFilter[Event Filtering]
        Debounce[Event Debouncing]
        ChangeQueue[Change Queue]
    end

    subgraph "Change Processing"
        FileCreate[File Creation]
        FileModify[File Modification]
        FileDelete[File Deletion]
        FileRename[File Rename]
    end

    subgraph "Synchronization"
        ParseAnalyze[Parse & Analyze]
        StoreModule[Store Module]
        UpdateIndex[Update Indexes]
        NotifyChange[Notify Changes]
    end

    subgraph "Project Population"
        FileDiscovery[File Discovery]
        BatchParse[Batch Parsing]
        ModuleAnalysis[Module Analysis]
        DependGraph[Dependency Graph]
    end

    FileWatch --> FSEvents
    FSEvents --> EventFilter
    EventFilter --> Debounce
    Debounce --> ChangeQueue

    ChangeQueue --> FileCreate
    ChangeQueue --> FileModify
    ChangeQueue --> FileDelete
    ChangeQueue --> FileRename

    FileCreate --> Synchronizer
    FileModify --> Synchronizer
    FileDelete --> Synchronizer
    FileRename --> Synchronizer

    Synchronizer --> ParseAnalyze
    ParseAnalyze --> StoreModule
    StoreModule --> UpdateIndex
    UpdateIndex --> NotifyChange

    ProjectPop --> FileDiscovery
    FileDiscovery --> BatchParse
    BatchParse --> ModuleAnalysis
    ModuleAnalysis --> DependGraph
```

## 9. Error Handling and Fault Tolerance

```mermaid
graph TB
    subgraph "Error Handling Strategy"
        ErrorBound[Error Boundaries]
        CircuitBreak[Circuit Breakers]
        Retry[Retry Logic]
        Fallback[Fallback Mechanisms]
    end

    subgraph "Supervision Strategy"
        OneForOne[One-for-One]
        OneForAll[One-for-All]
        RestForOne[Rest-for-One]
        SimpleOneForOne[Simple One-for-One]
    end

    subgraph "Recovery Mechanisms"
        StateRecovery[State Recovery]
        CacheRebuild[Cache Rebuild]
        IndexReconstruct[Index Reconstruction]
        PartialFailure[Partial Failure Handling]
    end

    subgraph "Monitoring & Alerting"
        HealthCheck[Health Checks]
        MetricsCollect[Metrics Collection]
        ErrorLogging[Error Logging]
        AlertSystem[Alert System]
    end

    ErrorBound --> CircuitBreak
    CircuitBreak --> Retry
    Retry --> Fallback

    OneForOne --> StateRecovery
    OneForAll --> CacheRebuild
    RestForOne --> IndexReconstruct
    SimpleOneForOne --> PartialFailure

    StateRecovery --> HealthCheck
    CacheRebuild --> MetricsCollect
    IndexReconstruct --> ErrorLogging
    PartialFailure --> AlertSystem
```

## Key Implementation Notes for BEAM/OTP Engineers

### 1. **ETS Table Strategy**
- `:set` tables for unique keys (modules, functions)
- `:bag` tables for one-to-many relationships (indexes)
- `{:read_concurrency, true}` for query-heavy tables
- `{:write_concurrency, true}` for update-heavy tables

### 2. **GenServer Design Patterns**
- Repository uses single GenServer with ETS backend for performance
- Memory Manager coordinates multiple specialized workers
- Pattern Matcher uses worker pool for concurrent analysis

### 3. **Supervision Strategy**
- Repository Supervisor: `:one_for_one` (independent services)
- Memory Manager Supervisor: `:rest_for_one` (dependent cleanup services)
- Performance Optimizer: `:one_for_one` (independent optimization workers)

### 4. **Memory Management**
- ETS memory monitoring with configurable thresholds
- Multi-level pressure response (clear cache → compress → cleanup → GC)
- Access pattern tracking for intelligent cleanup decisions

### 5. **Performance Optimizations**
- Batch processing for bulk operations
- Lazy loading for expensive analysis (CFG/DFG)
- Multi-level caching (query, analysis, CPG)
- Incremental updates vs. full rebuilds

### 6. **Error Handling**
- Circuit breakers for external dependencies
- Graceful degradation when analysis fails
- State recovery after process crashes
- Partial failure handling for batch operations
