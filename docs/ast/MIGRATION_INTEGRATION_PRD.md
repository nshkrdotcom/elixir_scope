# AST Layer Migration & Integration PRD

**Version:** 1.0  
**Date:** June 2025  
**Context:** Migration from Standalone AST to Foundation-Integrated AST Layer  
**Status:** Migration Planning

## Executive Summary

This document outlines the comprehensive migration strategy for integrating the existing ElixirScope AST codebase with the enhanced Foundation Layer (Layer 1) and its Infrastructure sub-layer. The migration will transform a standalone AST system into a fully integrated Layer 2 component that leverages Foundation services for configuration, error handling, telemetry, memory management, and resilience patterns.

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Target Architecture](#target-architecture)
3. [Migration Scope & Objectives](#migration-scope--objectives)
4. [Component Migration Plan](#component-migration-plan)
5. [Foundation Integration Requirements](#foundation-integration-requirements)
6. [Data Structure Enhancements](#data-structure-enhancements)
7. [API Contract Compliance](#api-contract-compliance)
8. [Testing Strategy](#testing-strategy)
9. [Migration Phases](#migration-phases)
10. [Risk Assessment & Mitigation](#risk-assessment--mitigation)

## Current State Analysis

### Existing AST Architecture

The current AST implementation consists of 8 major component areas:

#### 1. **Data Structures** (`data/`)
- **Core Components**: 8 modules (complexity_metrics.ex ~16KB, function_data.ex ~12KB)
- **Functionality**: Complete data models for modules, functions, complexity metrics
- **State**: Production-ready data structures with runtime correlation support
- **Dependencies**: Currently uses `ElixirScope.Utils` for utilities

#### 2. **Repository System** (`repository/`)
- **Core Components**: 3 main files (enhanced.ex ~22KB, enhanced_core.ex ~19KB, core.ex ~17KB)
- **Sub-systems**: Memory management (8 modules), project population (directory), synchronization
- **Functionality**: ETS-based storage, GenServer patterns, O(1) lookups
- **State**: Sophisticated repository with correlation capabilities
- **Dependencies**: Uses `ElixirScope.Storage.DataAccess` patterns

#### 3. **Analysis Engine** (`analysis/`)
- **Pattern Matcher**: 9 specialized modules with timing-based analysis
- **Performance Optimizer**: Sub-directory with optimization strategies
- **Functionality**: AST pattern detection, behavioral analysis, anti-pattern detection
- **State**: Complete pattern matching framework with caching

#### 4. **Query System** (`querying/`)
- **Core Components**: 7 modules including executor, optimizer, cache
- **Functionality**: SQL-like query interface with filtering, ordering, pagination
- **State**: Full query engine with validation and normalization
- **Dependencies**: Standalone query processing

#### 5. **Parsing System** (`parsing/`)
- **Core Components**: parser.ex (~12KB), instrumentation_mapper.ex (~17KB)
- **Sub-systems**: Analysis sub-directory
- **Functionality**: AST parsing with node ID assignment, instrumentation injection
- **State**: Advanced parsing with runtime correlation support

#### 6. **Memory Management** (`repository/memory_manager/`)
- **Core Components**: 8 specialized modules
- **Functionality**: Pressure handling, cache management, compression, monitoring
- **State**: Sophisticated memory management system
- **Dependencies**: Standalone memory management

#### 7. **Transformation System** (`transformation/`)
- **Functionality**: Code transformation and instrumentation injection
- **State**: Basic transformation capabilities

#### 8. **Compilation Integration** (`compilation/`)
- **Functionality**: Mix task integration for compilation pipeline
- **State**: Basic compilation integration

### Current Dependencies & Integration Points

```elixir
# Current external dependencies
ElixirScope.Utils                    # Utility functions
ElixirScope.Storage.DataAccess       # ETS storage patterns
ElixirScope.Config                   # Basic configuration (not Foundation)
```

### Strengths of Current Implementation

1. **Sophisticated Data Models**: Comprehensive module/function data with runtime correlation
2. **High-Performance Storage**: ETS-based repository with O(1) lookups
3. **Advanced Pattern Matching**: Complete pattern analysis framework
4. **Query Engine**: SQL-like interface with optimization
5. **Memory Management**: Sophisticated pressure handling and optimization
6. **Instrumentation**: Runtime correlation with AST node mapping
7. **GenServer Patterns**: Proper OTP design following ElixirScope patterns

### Migration Challenges

1. **Foundation Service Integration**: Need to replace standalone components with Foundation services
2. **Error Handling Standardization**: Must implement Foundation Infrastructure error contracts
3. **Memory Coordination**: Local memory management must coordinate with global Foundation system
4. **Health Check Implementation**: All major components need health check interfaces
5. **Telemetry Standardization**: Must emit standardized telemetry events
6. **Configuration Migration**: Move from basic config to Foundation Config service
7. **API Contract Compliance**: Must implement exact Foundation API contracts

## Target Architecture

### Foundation-Integrated AST Layer

```
ElixirScope.Foundation (Layer 1)
├── Foundation Services
│   ├── Config Service          → AST configuration management
│   ├── Event Store            → AST event storage
│   ├── Telemetry Service      → AST metrics collection
│   └── Error Handling         → AST error management
└── Infrastructure Sub-layer
    ├── MemoryManager          → Global memory coordination
    ├── HealthAggregator       → AST health monitoring
    ├── PerformanceMonitor     → AST performance tracking
    ├── CircuitBreakerWrapper  → AST operation protection
    └── RateLimiter           → AST query rate limiting

ElixirScope.AST (Layer 2) - MIGRATED
├── Data Models               → Enhanced with Foundation integration
├── Repository System         → Foundation-coordinated storage
├── Analysis Engine          → Foundation-monitored analysis
├── Query System             → Foundation-protected queries
├── Parsing System           → Foundation-resilient parsing
├── Memory Management        → Foundation-coordinated memory
└── Health & Telemetry       → Foundation-compliant reporting
```

## Migration Scope & Objectives

### Primary Objectives

1. **Foundation Service Integration**: Replace standalone services with Foundation service consumption
2. **API Contract Compliance**: Implement all Foundation API contracts exactly
3. **Enhanced Reliability**: Leverage Foundation Infrastructure for resilience
4. **Global Coordination**: Integrate with system-wide resource management
5. **Standardized Observability**: Implement Foundation-compliant health checks and telemetry
6. **Backward Compatibility**: Maintain existing AST functionality and APIs
7. **Performance Optimization**: Leverage Foundation Infrastructure for better performance

### Out of Scope

1. **Data Structure Changes**: Core AST data models remain unchanged
2. **Algorithm Changes**: Pattern matching and analysis algorithms remain unchanged
3. **Query Language Changes**: Query interface remains unchanged
4. **Major API Changes**: Public AST APIs remain backward compatible

## Component Migration Plan

### 1. Data Structures Migration

**Current State**: 8 data structure modules, production-ready
**Target State**: Foundation-integrated data structures with enhanced error handling

#### Required Changes:
- **Add Foundation Error Integration**: All functions return Foundation Error types
- **Add Telemetry Hooks**: Instrument data operations for Foundation monitoring
- **Configuration Integration**: Use Foundation Config for data structure limits

#### Migration Steps:
```elixir
# BEFORE (current)
defmodule ElixirScope.ASTRepository.ModuleData do
  alias ElixirScope.Utils
  
  def new(module_name, ast, opts \\ []) do
    # Current implementation
  end
end

# AFTER (migrated)
defmodule ElixirScope.AST.Data.ModuleData do
  alias ElixirScope.Foundation.{Config, Error, Telemetry}
  alias ElixirScope.Utils
  
  def new(module_name, ast, opts \\ []) do
    # Enhanced with Foundation integration
    start_time = System.monotonic_time(:microsecond)
    
    with {:ok, config} <- Config.get([:ast, :data, :module_data]),
         {:ok, result} <- do_create_module_data(module_name, ast, opts, config) do
      
      # Emit telemetry
      duration = System.monotonic_time(:microsecond) - start_time
      :ok = Telemetry.execute(
        [:elixir_scope, :ast, :data, :module_created],
        %{duration_microseconds: duration},
        %{module_name: module_name}
      )
      
      {:ok, result}
    else
      {:error, reason} -> 
        {:error, Error.new(:module_data_creation_failed, 
          "Failed to create module data", %{reason: reason})}
    end
  end
end
```

### 2. Repository System Migration

**Current State**: Sophisticated 3-tier repository with memory management
**Target State**: Foundation-coordinated repository with global integration

#### Key Changes:
- **Health Check Interface**: Implement `ElixirScope.Foundation.HealthCheckable`
- **Memory Coordination**: Integrate with `Foundation.Infrastructure.MemoryManager`
- **Configuration Migration**: Use Foundation Config service
- **Error Standardization**: Return Foundation Error types
- **Telemetry Integration**: Emit Foundation-compatible events

#### Migration Example:
```elixir
# Repository Core Migration
defmodule ElixirScope.AST.Repository.Core do
  use GenServer
  
  # Foundation Integration
  @behaviour ElixirScope.Foundation.HealthCheckable
  @behaviour ElixirScope.Foundation.Infrastructure.MemoryReporter
  
  alias ElixirScope.Foundation.{Config, Events, Telemetry, Error}
  alias ElixirScope.Foundation.Infrastructure.{
    MemoryManager, HealthAggregator, PerformanceMonitor
  }
  
  def start_link(opts) do
    {:ok, pid} = GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    
    # Register with Foundation Infrastructure
    :ok = HealthAggregator.register_health_check_source(
      :ast_repository_core,
      {__MODULE__, :health_check, []},
      interval_ms: 30_000
    )
    
    :ok = MemoryManager.register_memory_reporter(__MODULE__)
    
    {:ok, pid}
  end
  
  # Health Check Implementation (MANDATORY)
  @impl ElixirScope.Foundation.HealthCheckable
  def health_check() do
    case get_repository_stats() do
      {:ok, stats} when stats.error_count < 10 ->
        {:ok, %{
          status: :healthy,
          details: %{
            modules_count: stats.modules,
            functions_count: stats.functions,
            memory_usage_mb: stats.memory_mb,
            ets_tables: stats.tables,
            uptime_seconds: stats.uptime
          }
        }}
      {:ok, stats} ->
        {:ok, %{
          status: :degraded,
          details: %{
            modules_count: stats.modules,
            error_count: stats.error_count,
            last_error: stats.last_error,
            degradation_reason: "High error count"
          }
        }}
      {:error, reason} ->
        {:error, %{status: :critical, reason: reason}}
    end
  end
  
  # Memory Reporting Implementation (MANDATORY)
  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def report_memory_usage() do
    {:ok, %{
      component: :ast_repository,
      total_bytes: calculate_total_memory(),
      breakdown: %{
        modules_table: get_table_memory(:modules),
        functions_table: get_table_memory(:functions),
        correlation_index: get_table_memory(:correlation)
      },
      pressure_level: get_local_pressure_level(),
      last_cleanup: get_last_cleanup()
    }}
  end
  
  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def handle_pressure_signal(level) do
    case level do
      :critical -> trigger_emergency_cleanup()
      :high -> trigger_aggressive_cleanup()
      :medium -> trigger_gentle_cleanup()
      :low -> :ok
    end
  end
end
```

### 3. Analysis Engine Migration

**Current State**: 9-module pattern matcher with performance optimizer
**Target State**: Foundation-monitored analysis with health reporting

#### Key Changes:
- **Health Reporting**: Pattern matcher implements health checks
- **Telemetry Integration**: Detailed analysis metrics
- **Error Handling**: Foundation error types for analysis failures
- **Performance Monitoring**: Integration with Foundation PerformanceMonitor

### 4. Query System Migration

**Current State**: 7-module query engine with optimization
**Target State**: Foundation-protected query system with rate limiting

#### Key Changes:
- **Rate Limiting**: Complex queries protected by Foundation RateLimiter
- **Circuit Breaking**: Expensive operations protected by CircuitBreakerWrapper
- **Health Monitoring**: Query executor health checks
- **Performance Telemetry**: Query execution metrics

#### Migration Example:
```elixir
defmodule ElixirScope.AST.Querying.Executor do
  alias ElixirScope.Foundation.Infrastructure.{RateLimiter, CircuitBreakerWrapper}
  
  def execute_query(repo, query) do
    complexity = assess_query_complexity(query)
    client_id = get_client_id()
    
    case complexity do
      :high -> execute_protected_query(repo, query, client_id)
      _ -> execute_standard_query(repo, query)
    end
  end
  
  defp execute_protected_query(repo, query, client_id) do
    # Rate limiting for complex queries
    with :ok <- RateLimiter.check_rate(
           {:ast_complex_query, client_id}, 
           :ast_complex_queries_per_minute, 
           1
         ),
         {:ok, result} <- CircuitBreakerWrapper.execute(
           :ast_complex_queries, 
           fn -> do_execute_query(repo, query) end,
           30_000
         ) do
      {:ok, result}
    end
  end
end
```

### 5. Memory Management Migration

**Current State**: 8-module sophisticated memory management
**Target State**: Foundation-coordinated memory management

#### Key Changes:
- **Global Coordination**: Report to and coordinate with Foundation MemoryManager
- **Pressure Signals**: Respond to global memory pressure signals
- **Enhanced Cleanup**: Coordinate cleanup with global memory state

## Foundation Integration Requirements

### 1. Mandatory Behaviour Implementations

All major AST components MUST implement:

```elixir
@behaviour ElixirScope.Foundation.HealthCheckable
@behaviour ElixirScope.Foundation.Infrastructure.MemoryReporter  # For memory-intensive components
```

### 2. Required Service Integrations

#### Configuration Service Integration
```elixir
# Replace all direct config access with Foundation Config
ElixirScope.Foundation.Config.get([:ast, :parser, :timeout_ms])
ElixirScope.Foundation.Config.subscribe()  # For config updates
```

#### Event Service Integration
```elixir
# Store AST events via Foundation Events
event = ElixirScope.Foundation.Events.new_event(:ast_analysis_complete, data)
ElixirScope.Foundation.Events.store(event)
```

#### Telemetry Service Integration
```elixir
# Emit standardized telemetry
ElixirScope.Foundation.Telemetry.execute(
  [:elixir_scope, :ast, :parser, :parse_file_duration],
  measurements,
  metadata
)
```

### 3. Error Handling Migration

All functions must return Foundation Error types:

```elixir
# BEFORE
{:error, "Parse failed"}

# AFTER  
{:error, ElixirScope.Foundation.Error.new(
  :parse_failed, 
  "AST parsing failed", 
  %{file_path: path, reason: reason}
)}
```

## Data Structure Enhancements

### Configuration Schema Integration

```elixir
# Complete AST configuration schema for Foundation Config
%{
  ast: %{
    repository: %{
      max_modules: 50_000,
      max_functions: 500_000,
      ets_options: [:set, :public, {:read_concurrency, true}],
      health_check_interval_ms: 30_000
    },
    parser: %{
      timeout_ms: 30_000,
      max_file_size_bytes: 10_485_760,
      instrumentation_enabled: true
    },
    memory: %{
      pressure_thresholds: %{warning: 0.7, critical: 0.85, emergency: 0.95},
      cleanup_interval_ms: 60_000,
      report_interval_ms: 30_000
    },
    query: %{
      concurrent_limit: 50,
      complex_query_timeout_ms: 30_000,
      rate_limiting: %{
        enabled: true,
        queries_per_minute: 100,
        complex_queries_per_minute: 10
      }
    },
    pattern_matcher: %{
      timeout_ms: 5_000,
      confidence_threshold: 0.7,
      max_concurrent_analyses: 10
    }
  }
}
```

## API Contract Compliance

### Health Check Compliance

All major components must implement exact health check interface:

```elixir
def health_check() do
  {:ok, %{
    status: :healthy | :degraded | :critical,
    details: %{
      # Component-specific health metrics
      uptime_seconds: integer(),
      error_count: integer(),
      memory_usage_mb: float(),
      # ... other metrics
    }
  }}
end
```

### Telemetry Event Compliance

Required telemetry events (exact naming):

```elixir
# Parser events
[:elixir_scope, :ast, :parser, :parse_file_duration]
[:elixir_scope, :ast, :parser, :instrumentation_injection]

# Repository events  
[:elixir_scope, :ast, :repository, :module_stored]
[:elixir_scope, :ast, :repository, :query_executed]

# Memory events
[:elixir_scope, :ast, :memory, :pressure_level_changed]
[:elixir_scope, :ast, :memory, :cleanup_performed]

# Pattern matcher events
[:elixir_scope, :ast, :pattern_matcher, :analysis_complete]
```

## Testing Strategy

### 1. Unit Test Migration

Enhance existing tests with Foundation mocks:

```elixir
defmodule ElixirScope.AST.Test.FoundationMocks do
  defmodule MockConfig do
    def get([:ast, :parser, :timeout_ms]), do: {:ok, 30_000}
    def subscribe(), do: :ok
  end
  
  defmodule MockMemoryManager do
    def register_memory_reporter(_), do: :ok
    def subscribe_to_pressure_signals(), do: :ok
  end
end
```

### 2. Integration Tests

```elixir
defmodule ElixirScope.AST.FoundationIntegrationTest do
  test "repository integrates with Foundation MemoryManager" do
    # Start Foundation services
    start_supervised!(ElixirScope.Foundation.Infrastructure)
    start_supervised!(ElixirScope.AST.Repository.Core)
    
    # Test memory pressure coordination
    ElixirScope.Foundation.Infrastructure.MemoryManager.simulate_pressure(:high)
    
    # Verify AST responds appropriately
    assert_eventually(fn -> 
      memory_usage() < previous_usage * 0.8
    end)
  end
end
```

### 3. Contract Compliance Tests

```elixir
defmodule ElixirScope.AST.ContractComplianceTest do
  test "all major components implement health check interface" do
    components = [
      ElixirScope.AST.Repository.Core,
      ElixirScope.AST.Querying.Executor,
      ElixirScope.AST.Analysis.PatternMatcher.Core
    ]
    
    for component <- components do
      assert function_exported?(component, :health_check, 0)
      
      health_result = component.health_check()
      assert {:ok, %{status: status, details: details}} = health_result
      assert status in [:healthy, :degraded]
      assert is_map(details)
    end
  end
end
```

## Migration Phases

### Phase 1: Foundation Service Integration (Weeks 1-2)

**Scope**: Basic Foundation service consumption
**Components**: All data structures, basic repository functions
**Deliverables**:
- Foundation Config integration
- Foundation Error types
- Basic Foundation Events integration
- Foundation Telemetry integration

**Success Criteria**:
- All AST components use Foundation Config
- All functions return Foundation Error types
- Basic telemetry events are emitted
- No regression in existing functionality

### Phase 2: Infrastructure Integration (Weeks 3-4)

**Scope**: Foundation Infrastructure component integration
**Components**: Repository system, memory management, query system
**Deliverables**:
- Health check interfaces for all major components
- Memory coordination with Foundation MemoryManager
- Rate limiting for complex queries
- Circuit breaker protection for expensive operations

**Success Criteria**:
- All components report health status
- Memory pressure coordination works correctly
- Query rate limiting functions properly
- Circuit breakers protect against failures

### Phase 3: Advanced Features & Optimization (Weeks 5-6)

**Scope**: Advanced integration features and performance optimization
**Components**: Pattern matcher, parsing system, analysis engine
**Deliverables**:
- Complete telemetry event coverage
- Performance monitoring integration
- Advanced error handling and recovery
- Full API contract compliance

**Success Criteria**:
- All required telemetry events are emitted
- Performance monitoring shows detailed metrics
- Error handling follows all Foundation contracts
- 100% API contract compliance

### Phase 4: Testing & Validation (Weeks 7-8)

**Scope**: Comprehensive testing and production readiness
**Components**: All migrated components
**Deliverables**:
- Complete test suite with Foundation mocks
- Integration test coverage
- Contract compliance validation
- Performance benchmarking
- Documentation updates

**Success Criteria**:
- 95%+ test coverage with Foundation integration
- All contract compliance tests pass
- Performance meets or exceeds pre-migration levels
- Production readiness validation complete

## Risk Assessment & Mitigation

### High-Risk Areas

#### 1. Memory Management Coordination
**Risk**: Global memory coordination conflicts with local AST memory management
**Mitigation**: 
- Implement gradual coordination rollout
- Extensive testing of memory pressure scenarios
- Fallback to local-only management if coordination fails

#### 2. Performance Impact
**Risk**: Foundation integration adds latency overhead
**Mitigation**:
- Benchmark all integration points
- Optimize Foundation service calls
- Implement caching for frequently accessed Foundation data

#### 3. Complex Component Migration
**Risk**: Large components (enhanced.ex ~22KB) are difficult to migrate safely
**Mitigation**:
- Break down large components into smaller modules
- Incremental migration with feature flags
- Extensive regression testing

### Medium-Risk Areas

#### 4. API Contract Compliance
**Risk**: Missing or incorrect Foundation API contract implementation
**Mitigation**:
- Automated contract compliance testing
- Regular validation against contract specifications
- Foundation team review of integration code

#### 5. Configuration Migration
**Risk**: Configuration changes break existing AST functionality
**Mitigation**:
- Maintain backward compatibility during migration
- Gradual configuration migration with fallbacks
- Configuration validation testing

### Low-Risk Areas

#### 6. Data Structure Changes
**Risk**: Core data structures need modification
**Mitigation**: 
- Minimal changes to proven data structures
- Additive changes only (no breaking changes)
- Comprehensive data structure testing

## Success Metrics

### Performance Metrics
- **Parsing Performance**: <2% degradation from current performance
- **Query Performance**: <5% degradation for complex queries
- **Memory Usage**: <10% increase in baseline memory usage
- **Response Time**: <1ms average overhead for Foundation service calls

### Integration Metrics
- **Health Check Coverage**: 100% of major components
- **Telemetry Coverage**: 100% of required events
- **Error Handling**: 100% Foundation Error type compliance
- **Configuration**: 100% migration to Foundation Config

### Quality Metrics
- **Test Coverage**: >95% with Foundation integration tests
- **Contract Compliance**: 100% API contract compliance
- **Zero Regressions**: No functional regressions in existing AST features
- **Documentation**: 100% updated documentation for migrated components

## Migration Deliverables

1. **Migrated Codebase**: Complete AST layer with Foundation integration
2. **Test Suite**: Comprehensive tests with Foundation mocks and integration tests
3. **Documentation**: Updated API documentation and integration guides
4. **Configuration**: Complete AST configuration schema for Foundation Config
5. **Monitoring**: Health checks, telemetry, and performance monitoring setup
6. **Migration Guide**: Detailed guide for operators migrating existing AST deployments

---

**Migration Team**: ElixirScope AST Team + Foundation Integration Team  
**Estimated Effort**: 8 weeks (2 developers)  
**Dependencies**: Enhanced Foundation Layer must be production-ready  
**Review Cycle**: Weekly migration progress reviews  
**Go-Live Target**: Q3 2025 