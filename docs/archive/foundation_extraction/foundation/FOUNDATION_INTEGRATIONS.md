# ElixirScope Foundation Layer Integration Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Integration Patterns](#integration-patterns)
4. [Layer-by-Layer Integration](#layer-by-layer-integration)
   - [Layer 2: AST Operations](#layer-2-ast-operations)
   - [Layer 3: Graph Algorithms](#layer-3-graph-algorithms)
   - [Layer 4: CPG (Code Property Graph)](#layer-4-cpg-code-property-graph)
   - [Layer 5: Analysis](#layer-5-analysis)
   - [Layer 6: Query](#layer-6-query)
   - [Layer 7: Capture](#layer-7-capture)
   - [Layer 8: Intelligence/AI](#layer-8-intelligenceai)
   - [Layer 9: Debugger](#layer-9-debugger)
5. [Data Flow Diagrams](#data-flow-diagrams)
6. [API Contracts](#api-contracts)
7. [Error Handling Strategy](#error-handling-strategy)
8. [Performance Considerations](#performance-considerations)
9. [Monitoring and Telemetry](#monitoring-and-telemetry)
10. [Testing Strategy](#testing-strategy)
11. [Deployment Considerations](#deployment-considerations)

---

## Introduction

The ElixirScope Foundation layer serves as the robust infrastructure backbone for the complete 9-layer ElixirScope system. This document provides comprehensive engineering guidance on how layers 2-9 integrate with and leverage the Foundation layer's capabilities.

The Foundation layer (Layer 1) provides:
- **Configuration Management**: Dynamic, validated configuration system
- **Event System**: Structured event handling and storage
- **Telemetry**: Comprehensive metrics collection and monitoring
- **Service Registry**: Service discovery and health management
- **Infrastructure Protection**: Circuit breakers, rate limiting, connection pooling
- **Error Handling**: Structured error context and recovery strategies
- **Utilities**: Common operations, measuring tools, and system introspection

This integration guide ensures that all higher layers can reliably and efficiently leverage these foundational capabilities while maintaining system-wide consistency, observability, and resilience.

---

## Architecture Overview

The ElixirScope system follows a layered architecture where each layer builds upon the capabilities of the layers below it. The Foundation layer provides essential infrastructure services that all higher layers depend on.

### Layer Dependencies

```
Layer 9: Debugger           ┐
Layer 8: Intelligence/AI    ├─── All depend on Foundation
Layer 7: Capture            │
Layer 6: Query              │
Layer 5: Analysis           │
Layer 4: CPG                │
Layer 3: Graph Algorithms   │
Layer 2: AST Operations     ┘
Layer 1: Foundation (Infrastructure)
```

### Core Integration Principles

1. **Uniform Error Handling**: All layers use Foundation's structured error system
2. **Consistent Configuration**: All layers register and consume configuration through Foundation
3. **Comprehensive Telemetry**: All operations emit telemetry through Foundation's system
4. **Service Discovery**: All services register with Foundation's service registry
5. **Infrastructure Protection**: All external calls use Foundation's protection mechanisms
6. **Event-Driven Communication**: Inter-layer communication uses Foundation's event system

### Foundation Services Overview

| Service Category | Components | Purpose |
|-----------------|------------|---------|
| Configuration | Config, Validation | Dynamic system configuration |
| Event System | Events, Storage, Relationships | Structured event handling |
| Telemetry | Metrics, Handlers | System observability |
| Service Management | ServiceRegistry, ProcessRegistry | Service discovery |
| Infrastructure | CircuitBreakers, RateLimiting | System protection |
| Error Handling | Error, ErrorContext | Structured error management |
| Utilities | Utils, Measurement | Common operations |

---

## Integration Patterns

### Pattern 1: Service Initialization

All higher-layer services follow this initialization pattern:

```elixir
defmodule ElixirScope.Layer2.ASTParser do
  use GenServer
  alias ElixirScope.Foundation

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, 
      name: Foundation.ServiceRegistry.via_tuple(:production, :ast_parser)
    )
  end

  def init(opts) do
    # Register with service registry happens automatically via via_tuple
    
    # Subscribe to configuration changes
    :ok = Foundation.Config.subscribe()
    
    # Load initial configuration
    config = Foundation.Config.get([:ast, :parser], %{})
    
    # Emit initialization telemetry
    Foundation.Telemetry.emit_counter([:ast_parser, :initialized])
    
    {:ok, %{config: config, stats: %{}}}
  end
end
```

### Pattern 2: Protected External Operations

All external service calls use Foundation's infrastructure protection:

```elixir
def call_external_service(data) do
  context = Foundation.ErrorContext.new(__MODULE__, :call_external_service, 
    metadata: %{data_size: byte_size(data)}
  )
  
  Foundation.Infrastructure.execute_protected(
    :external_service_call,
    [
      circuit_breaker: :external_api_breaker,
      rate_limiter: {:api_calls, "service_user"}
    ],
    fn ->
      Foundation.ErrorContext.with_context(context, fn ->
        ExternalAPI.process(data)
      end)
    end
  )
end
```

### Pattern 3: Event-Driven Communication

Layers communicate through Foundation's event system:

```elixir
# Layer 2 emits AST parsed event
{:ok, event} = Foundation.Events.new_event(
  :ast_parsed,
  %{
    file_path: file_path,
    node_count: node_count,
    parse_time_ms: parse_time
  },
  correlation_id: correlation_id,
  metadata: %{layer: 2, service: :ast_parser}
)

{:ok, _event_id} = Foundation.Events.store(event)

# Layer 3 subscribes to AST events
def handle_info({:event_notification, %{type: :ast_parsed} = event}, state) do
  # Process the AST for graph construction
  process_ast_for_graph(event.data)
  {:noreply, state}
end
```

### Pattern 4: Configuration Management

Each layer manages its configuration through Foundation:

```elixir
defmodule ElixirScope.Layer5.Analysis.Config do
  alias ElixirScope.Foundation

  @config_schema %{
    pattern_detection: %{
      enabled: {:boolean, true},
      max_patterns: {:integer, 1000, min: 1, max: 10000},
      timeout_ms: {:integer, 5000, min: 100, max: 30000}
    },
    quality_assessment: %{
      enabled: {:boolean, true},
      thresholds: %{
        complexity: {:integer, 10, min: 1, max: 100},
        duplication: {:float, 0.1, min: 0.0, max: 1.0}
      }
    }
  }

  def load_config do
    Foundation.Config.get_with_validation([:analysis], @config_schema)
  end

  def update_pattern_threshold(new_threshold) do
    Foundation.Config.update([:analysis, :quality_assessment, :thresholds, :complexity], new_threshold)
  end
end
```

---

## Layer-by-Layer Integration

### Layer 2: AST Operations

**Purpose**: Parse Elixir source code into Abstract Syntax Trees and provide AST manipulation operations.

**Foundation Dependencies**:
- Configuration for parser settings and optimization flags
- Telemetry for parse timing and success/failure metrics
- Error handling for syntax errors and file I/O issues
- Event system for AST completion notifications
- Service registry for parser worker discovery

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer2.ASTRepository do
  alias ElixirScope.Foundation

  # Configuration integration
  def get_parser_config do
    Foundation.Config.get_with_validation(
      [:ast, :parser],
      %{
        timeout_ms: {:integer, 5000, min: 100, max: 30000},
        max_file_size_mb: {:integer, 10, min: 1, max: 100},
        parallel_workers: {:integer, 4, min: 1, max: 16}
      }
    )
  end

  # Telemetry integration
  def parse_file(file_path) do
    start_time = System.monotonic_time(:millisecond)
    
    result = Foundation.ErrorContext.with_context(
      Foundation.ErrorContext.new(__MODULE__, :parse_file, 
        metadata: %{file_path: file_path}
      ),
      fn ->
        do_parse_file(file_path)
      end
    )
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    case result do
      {:ok, ast} ->
        Foundation.Telemetry.emit_counter([:ast, :parse, :success])
        Foundation.Telemetry.emit_histogram([:ast, :parse, :duration], duration)
        Foundation.Telemetry.emit_gauge([:ast, :nodes, :count], count_nodes(ast))
        
        # Emit event for other layers
        Foundation.Events.emit_async(:ast_parsed, %{
          file_path: file_path,
          node_count: count_nodes(ast),
          duration_ms: duration
        })
        
        {:ok, ast}
      
      {:error, reason} ->
        Foundation.Telemetry.emit_counter([:ast, :parse, :error])
        Foundation.Error.emit(:parse_failed, %{file_path: file_path, reason: reason})
        {:error, reason}
    end
  end
end
```

**Service Registration**:
```elixir
# AST services register with Foundation
Foundation.ServiceRegistry.register(:production, :ast_parser, self(), %{
  type: :parser,
  capabilities: [:elixir_parsing, :pattern_matching],
  health_check: &health_check/0
})
```

### Layer 3: Graph Algorithms

**Purpose**: Transform AST data into graph structures and perform graph-based analyses.

**Foundation Dependencies**:
- Configuration for algorithm parameters and optimization settings
- Telemetry for algorithm performance and resource usage
- Event system to receive AST updates and emit graph analysis results
- Service registry for algorithm worker management
- Infrastructure protection for memory-intensive operations

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer3.GraphBuilder do
  alias ElixirScope.Foundation

  # Event-driven AST processing
  def handle_info({:event_notification, %{type: :ast_parsed} = event}, state) do
    # Use infrastructure protection for memory-intensive graph building
    result = Foundation.Infrastructure.execute_protected(
      :graph_construction,
      [
        circuit_breaker: :memory_operations,
        rate_limiter: {:graph_builds, "system"},
        timeout: 30_000
      ],
      fn ->
        build_graph_from_ast(event.data)
      end
    )
    
    case result do
      {:ok, graph} ->
        Foundation.Telemetry.emit_gauge([:graph, :nodes], Graph.node_count(graph))
        Foundation.Telemetry.emit_gauge([:graph, :edges], Graph.edge_count(graph))
        
        # Emit graph ready event
        Foundation.Events.emit_async(:graph_constructed, %{
          source_file: event.data.file_path,
          node_count: Graph.node_count(graph),
          edge_count: Graph.edge_count(graph)
        })
        
        {:noreply, %{state | graphs: Map.put(state.graphs, event.data.file_path, graph)}}
      
      {:error, reason} ->
        Foundation.Error.emit(:graph_construction_failed, %{
          file_path: event.data.file_path,
          reason: reason
        })
        {:noreply, state}
    end
  end

  # Algorithm execution with telemetry
  def run_centrality_analysis(graph, algorithm \\ :betweenness) do
    Foundation.Measurement.measure([:graph, :centrality, algorithm], fn ->
      Foundation.ErrorContext.with_context(
        Foundation.ErrorContext.new(__MODULE__, :run_centrality_analysis,
          metadata: %{algorithm: algorithm, node_count: Graph.node_count(graph)}
        ),
        fn ->
          Graph.Algorithms.centrality(graph, algorithm)
        end
      )
    end)
  end
end
```

### Layer 4: CPG (Code Property Graph)

**Purpose**: Create Code Property Graphs combining Control Flow Graphs (CFG) and Data Flow Graphs (DFG).

**Foundation Dependencies**:
- Configuration for CPG construction parameters
- Telemetry for CPG creation and query performance
- Event system to consume graph data and emit CPG completion
- Error handling for complex graph analysis failures
- Service registry for CPG worker processes

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer4.CPGBuilder do
  alias ElixirScope.Foundation

  def construct_cpg(graph_data) do
    config = Foundation.Config.get([:cpg, :construction], %{
      max_depth: 50,
      enable_data_flow: true,
      enable_control_flow: true,
      timeout_ms: 60_000
    })
    
    Foundation.Measurement.measure([:cpg, :construction], fn ->
      Foundation.Infrastructure.execute_protected(
        :cpg_construction,
        [
          circuit_breaker: :intensive_analysis,
          timeout: config.timeout_ms
        ],
        fn ->
          context = Foundation.ErrorContext.new(__MODULE__, :construct_cpg,
            metadata: %{
              source_nodes: graph_data.node_count,
              config: config
            }
          )
          
          Foundation.ErrorContext.with_context(context, fn ->
            # Build CFG
            cfg = build_control_flow_graph(graph_data, config)
            Foundation.Telemetry.emit_gauge([:cpg, :cfg, :nodes], CFG.node_count(cfg))
            
            # Build DFG if enabled
            dfg = if config.enable_data_flow do
              build_data_flow_graph(graph_data, config)
            else
              nil
            end
            
            # Combine into CPG
            cpg = combine_graphs(cfg, dfg, config)
            
            Foundation.Events.emit_async(:cpg_constructed, %{
              source_file: graph_data.source_file,
              cfg_nodes: CFG.node_count(cfg),
              dfg_nodes: if(dfg, do: DFG.node_count(dfg), else: 0),
              cpg_complexity: CPG.complexity_score(cpg)
            })
            
            {:ok, cpg}
          end)
        end
      )
    end)
  end
end
```

### Layer 5: Analysis

**Purpose**: Perform pattern detection, quality assessment, and security analysis on CPG data.

**Foundation Dependencies**:
- Configuration for analysis thresholds and enabled analyzers
- Telemetry for analysis performance and findings
- Event system to consume CPG data and emit analysis results
- Error handling for analysis failures
- Infrastructure protection for resource-intensive analysis

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer5.PatternDetector do
  alias ElixirScope.Foundation

  def analyze_patterns(cpg) do
    config = Foundation.Config.get_with_validation(
      [:analysis, :patterns],
      %{
        enabled_patterns: {:list, [:anti_patterns, :code_smells, :security_issues]},
        complexity_threshold: {:integer, 10, min: 1, max: 100},
        max_analysis_time_ms: {:integer, 30_000, min: 1000, max: 300_000}
      }
    )
    
    Foundation.Infrastructure.execute_protected(
      :pattern_analysis,
      [
        circuit_breaker: :analysis_operations,
        timeout: config.max_analysis_time_ms,
        rate_limiter: {:pattern_analysis, "system"}
      ],
      fn ->
        results = Foundation.Measurement.measure([:analysis, :pattern_detection], fn ->
          Enum.reduce(config.enabled_patterns, %{}, fn pattern_type, acc ->
            pattern_results = detect_pattern_type(cpg, pattern_type, config)
            
            Foundation.Telemetry.emit_counter([:analysis, :patterns, pattern_type], 
              length(pattern_results))
            
            Map.put(acc, pattern_type, pattern_results)
          end)
        end)
        
        # Emit analysis completed event
        Foundation.Events.emit_async(:pattern_analysis_completed, %{
          source_file: cpg.source_file,
          patterns_found: Enum.map(results, fn {type, patterns} -> 
            {type, length(patterns)} 
          end),
          total_issues: Enum.sum(Enum.map(results, fn {_, patterns} -> length(patterns) end))
        })
        
        {:ok, results}
      end
    )
  end

  # Security analysis with comprehensive error handling
  def security_analysis(cpg) do
    Foundation.ErrorContext.with_context(
      Foundation.ErrorContext.new(__MODULE__, :security_analysis,
        metadata: %{source_file: cpg.source_file, cpg_complexity: CPG.complexity(cpg)}
      ),
      fn ->
        security_rules = Foundation.Config.get([:analysis, :security, :rules], [])
        
        violations = Enum.flat_map(security_rules, fn rule ->
          apply_security_rule(cpg, rule)
        end)
        
        Foundation.Telemetry.emit_counter([:analysis, :security, :violations], length(violations))
        
        if length(violations) > 0 do
          Foundation.Events.emit_async(:security_violations_found, %{
            source_file: cpg.source_file,
            violation_count: length(violations),
            severity_breakdown: group_by_severity(violations)
          })
        end
        
        {:ok, violations}
      end
    )
  end
end
```

### Layer 6: Query

**Purpose**: Provide multi-dimensional query capabilities across AST, graph, CPG, and analysis data.

**Foundation Dependencies**:
- Configuration for query optimization and caching settings
- Telemetry for query performance metrics
- Event system for query result notifications
- Service registry for query engine workers
- Infrastructure protection for complex queries

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer6.QueryEngine do
  alias ElixirScope.Foundation

  def execute_query(query_spec, opts \\ []) do
    config = Foundation.Config.get([:query, :execution], %{
      max_execution_time_ms: 30_000,
      enable_caching: true,
      max_result_size: 10_000
    })
    
    # Check cache first
    cache_key = generate_cache_key(query_spec)
    
    case Foundation.Config.get([:query, :cache, :enabled], true) do
      true ->
        case lookup_cache(cache_key) do
          {:hit, result} ->
            Foundation.Telemetry.emit_counter([:query, :cache, :hit])
            {:ok, result}
          
          :miss ->
            Foundation.Telemetry.emit_counter([:query, :cache, :miss])
            execute_and_cache_query(query_spec, cache_key, config)
        end
      
      false ->
        execute_query_direct(query_spec, config)
    end
  end

  defp execute_and_cache_query(query_spec, cache_key, config) do
    Foundation.Infrastructure.execute_protected(
      :query_execution,
      [
        circuit_breaker: :query_operations,
        timeout: config.max_execution_time_ms,
        rate_limiter: {:queries, "system"}
      ],
      fn ->
        result = Foundation.Measurement.measure([:query, :execution], fn ->
          Foundation.ErrorContext.with_context(
            Foundation.ErrorContext.new(__MODULE__, :execute_query,
              metadata: %{query_type: query_spec.type, complexity: query_spec.complexity}
            ),
            fn ->
              execute_query_logic(query_spec, config)
            end
          )
        end)
        
        case result do
          {:ok, data} when length(data) <= config.max_result_size ->
            cache_result(cache_key, data)
            
            Foundation.Events.emit_async(:query_completed, %{
              query_type: query_spec.type,
              result_count: length(data),
              cached: true
            })
            
            {:ok, data}
          
          {:ok, data} ->
            Foundation.Telemetry.emit_counter([:query, :result, :too_large])
            Foundation.Error.emit(:query_result_too_large, %{
              size: length(data),
              max_size: config.max_result_size
            })
            {:error, :result_too_large}
          
          {:error, reason} ->
            Foundation.Error.emit(:query_execution_failed, %{
              query_spec: query_spec,
              reason: reason
            })
            {:error, reason}
        end
      end
    )
  end
end
```

### Layer 7: Capture

**Purpose**: Capture runtime execution traces, instrument code, and correlate execution events.

**Foundation Dependencies**:
- Configuration for instrumentation scope and storage settings
- Telemetry for capture performance and data volume metrics
- Event system for execution trace events and correlation
- Service registry for capture worker management
- Infrastructure protection for high-volume data capture

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer7.ExecutionCapture do
  alias ElixirScope.Foundation

  def start_capture(target_module, capture_opts \\ []) do
    config = Foundation.Config.get_with_validation(
      [:capture, :execution],
      %{
        max_trace_depth: {:integer, 100, min: 1, max: 1000},
        sampling_rate: {:float, 0.1, min: 0.001, max: 1.0},
        buffer_size: {:integer, 10_000, min: 100, max: 100_000},
        storage_backend: {:atom, :ets, values: [:ets, :mnesia, :external]}
      }
    )
    
    Foundation.Infrastructure.execute_protected(
      :execution_capture,
      [
        rate_limiter: {:capture_starts, "system"},
        circuit_breaker: :instrumentation_ops
      ],
      fn ->
        # Initialize capture context
        capture_id = Foundation.Utils.generate_id()
        
        capture_context = %{
          id: capture_id,
          target_module: target_module,
          start_time: System.monotonic_time(:microsecond),
          config: config,
          trace_buffer: []
        }
        
        # Set up instrumentation
        :ok = instrument_module(target_module, capture_context)
        
        Foundation.Telemetry.emit_counter([:capture, :started])
        Foundation.Telemetry.emit_gauge([:capture, :active], get_active_captures() + 1)
        
        # Emit capture started event
        Foundation.Events.emit_async(:capture_started, %{
          capture_id: capture_id,
          target_module: target_module,
          config: config
        })
        
        {:ok, capture_id}
      end
    )
  end

  def handle_trace_event(capture_id, event_data) do
    # High-volume trace processing with sampling
    config = get_capture_config(capture_id)
    
    if should_sample?(config.sampling_rate) do
      Foundation.ErrorContext.with_context(
        Foundation.ErrorContext.new(__MODULE__, :handle_trace_event,
          metadata: %{capture_id: capture_id, event_type: event_data.type}
        ),
        fn ->
          # Store trace event
          :ok = store_trace_event(capture_id, event_data)
          
          Foundation.Telemetry.emit_counter([:capture, :events, :stored])
          
          # Emit for correlation by other layers
          Foundation.Events.emit_async(:trace_event_captured, %{
            capture_id: capture_id,
            event_type: event_data.type,
            timestamp: event_data.timestamp,
            correlation_data: event_data.correlation_data
          })
        end
      )
    else
      Foundation.Telemetry.emit_counter([:capture, :events, :sampled_out])
    end
  end
end
```

### Layer 8: Intelligence/AI

**Purpose**: Provide AI-powered code analysis, predictions, and insights using multiple AI providers.

**Foundation Dependencies**:
- Configuration for AI provider settings and model parameters
- Telemetry for AI request performance and accuracy metrics
- Event system to consume analysis data and emit AI insights
- Service registry for AI worker processes
- Infrastructure protection for external AI API calls
- Error handling for AI service failures and rate limits

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer8.AIAnalyzer do
  alias ElixirScope.Foundation

  def analyze_code_quality(analysis_data) do
    config = Foundation.Config.get_with_validation(
      [:ai, :code_quality],
      %{
        primary_provider: {:atom, :openai, values: [:openai, :anthropic, :google]},
        fallback_providers: {:list, [:anthropic, :google]},
        max_context_tokens: {:integer, 4000, min: 100, max: 32000},
        confidence_threshold: {:float, 0.7, min: 0.0, max: 1.0}
      }
    )
    
    providers = [config.primary_provider | config.fallback_providers]
    
    Foundation.Infrastructure.execute_protected(
      :ai_analysis,
      [
        circuit_breaker: :ai_providers,
        rate_limiter: {:ai_requests, "system"},
        timeout: 30_000
      ],
      fn ->
        result = Foundation.Measurement.measure([:ai, :analysis, :duration], fn ->
          attempt_ai_analysis_with_fallback(analysis_data, providers, config)
        end)
        
        case result do
          {:ok, insights} ->
            Foundation.Telemetry.emit_counter([:ai, :analysis, :success])
            Foundation.Telemetry.emit_gauge([:ai, :insights, :confidence], 
              insights.confidence_score)
            
            # Emit AI insights event
            Foundation.Events.emit_async(:ai_insights_generated, %{
              source_file: analysis_data.source_file,
              insight_type: :code_quality,
              confidence: insights.confidence_score,
              provider: insights.provider,
              insights_count: length(insights.suggestions)
            })
            
            {:ok, insights}
          
          {:error, reason} ->
            Foundation.Error.emit(:ai_analysis_failed, %{
              source_file: analysis_data.source_file,
              providers_attempted: providers,
              reason: reason
            })
            {:error, reason}
        end
      end
    )
  end

  defp attempt_ai_analysis_with_fallback(data, [provider | fallback_providers], config) do
    Foundation.ErrorContext.with_context(
      Foundation.ErrorContext.new(__MODULE__, :ai_request,
        metadata: %{provider: provider, data_size: byte_size(inspect(data))}
      ),
      fn ->
        case call_ai_provider(provider, data, config) do
          {:ok, result} ->
            Foundation.Telemetry.emit_counter([:ai, :provider, :success], %{provider: provider})
            {:ok, Map.put(result, :provider, provider)}
          
          {:error, :rate_limited} when fallback_providers != [] ->
            Foundation.Telemetry.emit_counter([:ai, :provider, :rate_limited], %{provider: provider})
            attempt_ai_analysis_with_fallback(data, fallback_providers, config)
          
          {:error, reason} when fallback_providers != [] ->
            Foundation.Telemetry.emit_counter([:ai, :provider, :error], %{provider: provider})
            attempt_ai_analysis_with_fallback(data, fallback_providers, config)
          
          {:error, reason} ->
            {:error, reason}
        end
      end
    )
  end
end
```

### Layer 9: Debugger

**Purpose**: Provide time-travel debugging, visualization, and AI-assisted debugging capabilities.

**Foundation Dependencies**:
- Configuration for debugger settings and UI preferences
- Telemetry for debugging session metrics and performance
- Event system to consume all layer data for debugging context
- Service registry for debugger component management
- Infrastructure protection for intensive debugging operations
- Error handling for debugging tool failures

**Key Integration Points**:

```elixir
defmodule ElixirScope.Layer9.TimeTravelDebugger do
  alias ElixirScope.Foundation

  def start_debug_session(target_info, debug_opts \\ []) do
    config = Foundation.Config.get_with_validation(
      [:debugger, :session],
      %{
        max_history_size: {:integer, 1000, min: 10, max: 10000},
        enable_ai_assistance: {:boolean, true},
        visualization_depth: {:integer, 5, min: 1, max: 20},
        snapshot_interval_ms: {:integer, 100, min: 10, max: 10000}
      }
    )
    
    Foundation.Infrastructure.execute_protected(
      :debug_session_start,
      [
        circuit_breaker: :debugging_operations,
        rate_limiter: {:debug_sessions, "user"}
      ],
      fn ->
        session_id = Foundation.Utils.generate_id()
        
        session_context = %{
          id: session_id,
          target: target_info,
          config: config,
          start_time: System.monotonic_time(:microsecond),
          history: [],
          active_breakpoints: []
        }
        
        # Subscribe to all relevant events for debugging context
        :ok = Foundation.Events.subscribe([
          :ast_parsed, :graph_constructed, :cpg_constructed,
          :pattern_analysis_completed, :query_completed,
          :trace_event_captured, :ai_insights_generated
        ])
        
        Foundation.Telemetry.emit_counter([:debugger, :sessions, :started])
        Foundation.Telemetry.emit_gauge([:debugger, :sessions, :active], 
          get_active_sessions() + 1)
        
        # Emit debug session started event
        Foundation.Events.emit_async(:debug_session_started, %{
          session_id: session_id,
          target: target_info,
          config: config
        })
        
        {:ok, session_id}
      end
    )
  end

  def handle_info({:event_notification, event}, %{session_id: session_id} = state) do
    # Collect all events for time-travel debugging context
    Foundation.ErrorContext.with_context(
      Foundation.ErrorContext.new(__MODULE__, :handle_debug_event,
        metadata: %{session_id: session_id, event_type: event.type}
      ),
      fn ->
        # Add event to debug history
        updated_history = add_to_debug_history(state.history, event, state.config)
        
        # Check if this event triggers any breakpoints
        triggered_breakpoints = check_breakpoints(event, state.active_breakpoints)
        
        if length(triggered_breakpoints) > 0 do
          Foundation.Events.emit_async(:breakpoint_triggered, %{
            session_id: session_id,
            event: event,
            breakpoints: triggered_breakpoints
          })
          
          Foundation.Telemetry.emit_counter([:debugger, :breakpoints, :triggered])
        end
        
        Foundation.Telemetry.emit_counter([:debugger, :events, :processed])
        
        {:noreply, %{state | history: updated_history}}
      end
    )
  end

  def get_ai_debugging_assistance(session_id, error_context) do
    Foundation.Infrastructure.execute_protected(
      :ai_debug_assistance,
      [
        circuit_breaker: :ai_providers,
        rate_limiter: {:ai_debug_requests, "user"},
        timeout: 20_000
      ],
      fn ->
        # Gather debugging context from all layers
        debug_context = gather_debug_context(session_id, error_context)
        
        # Use Layer 8 AI services for debugging assistance
        case ElixirScope.Layer8.AIAnalyzer.analyze_debugging_context(debug_context) do
          {:ok, suggestions} ->
            Foundation.Telemetry.emit_counter([:debugger, :ai_assistance, :success])
            
            Foundation.Events.emit_async(:ai_debug_suggestions_generated, %{
              session_id: session_id,
              suggestion_count: length(suggestions.recommendations),
              confidence: suggestions.confidence_score
            })
            
            {:ok, suggestions}
          
          {:error, reason} ->
            Foundation.Error.emit(:ai_debug_assistance_failed, %{
              session_id: session_id,
              error_context: error_context,
              reason: reason
            })
            {:error, reason}
        end
      end
    )
  end
end
```
