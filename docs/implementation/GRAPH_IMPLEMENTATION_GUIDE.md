# Graph Layer Implementation Guide - Hybrid libgraph Approach

**Version:** 2.0  
**Date:** December 6, 2025  
**Layer:** Graph Layer (Layer 3)  
**Status:** Ready for Implementation (Phase 2, Week 2)

## Overview

The Graph Layer provides mathematical graph operations and algorithms used by higher layers (CPG, Analysis) for code analysis. **Updated Strategy**: We use a hybrid approach with libgraph as the foundation plus custom code analysis extensions.

## Why Hybrid libgraph Approach

### Strategic Advantages
- **70% Faster Implementation**: Proven algorithms vs custom coding
- **Lower Bug Risk**: Battle-tested pathfinding, centrality algorithms
- **Production Ready**: Mature library with comprehensive algorithm coverage
- **Foundation Integration**: Via wrapper layer for telemetry/configuration
- **Extensibility**: Custom algorithms for code-specific analysis
- **Quick Wins**: Can implement core functionality in 2-3 days

### libgraph Benefits
- **Proven Algorithms**: Dijkstra, A*, Bellman-Ford, SCC, topological sorting
- **Memory Efficiency**: Compact representation, efficient data structures
- **API Design**: Clean, functional interface with comprehensive type specs
- **DOT Export**: Built-in visualization support for debugging

## Architecture

### Hybrid Module Structure
```
lib/elixir_scope/graph/
├── core.ex                     # libgraph integration wrapper
├── foundation_integration.ex   # Telemetry & configuration wrappers
├── algorithms/
│   ├── code_centrality.ex      # AST-specific centrality measures
│   ├── dependency_analysis.ex  # Code dependency pathfinding
│   ├── module_clustering.ex    # Module community detection
│   ├── temporal_analysis.ex    # Code evolution analysis
│   └── ml_analysis.ex          # ML-based graph analysis
├── converters.ex               # AST/CPG to libgraph conversion
└── utils.ex                    # Helper functions
```

### Data Structures

#### libgraph Integration
```elixir
defmodule ElixirScope.Graph.Core do
  @type graph :: Graph.t()
  @type vertex :: term()
  @type edge :: Graph.Edge.t()
  @type path :: [vertex()]
  @type distance :: number() | :infinity
  
  # libgraph wrapper with Foundation integration
  def new_graph(type \\ :directed) do
    case type do
      :directed -> Graph.new(type: :directed)
      :undirected -> Graph.new(type: :undirected)
    end
  end
end
```

## Implementation Priority

### Phase 1: libgraph Integration (Days 1-2)
```elixir
# 1. Add libgraph dependency and basic wrappers
mix deps.get  # Add {:libgraph, "~> 0.16"}

# 2. Foundation integration layer
ElixirScope.Graph.FoundationIntegration.measure_algorithm/3
ElixirScope.Graph.FoundationIntegration.emit_metrics/2
ElixirScope.Graph.FoundationIntegration.get_config/1

# 3. Core libgraph wrappers
ElixirScope.Graph.Core.shortest_path_with_telemetry/3
ElixirScope.Graph.Core.centrality_with_config/2
ElixirScope.Graph.Core.connected_components_measured/1
```

### Phase 2: Code Analysis Extensions (Days 3-4)
```elixir
# 4. AST-specific algorithms (custom implementations)
ElixirScope.Graph.Algorithms.CodeCentrality.dependency_importance/1
ElixirScope.Graph.Algorithms.DependencyAnalysis.circular_dependencies/1
ElixirScope.Graph.Algorithms.ModuleClustering.cohesive_modules/2

# 5. Converters for ElixirScope data types
ElixirScope.Graph.Converters.ast_to_graph/1
ElixirScope.Graph.Converters.cpg_to_graph/1
```

### Phase 3: Advanced Analysis (Days 5-6)
```elixir
# 6. Temporal and ML analysis (domain-specific)
ElixirScope.Graph.Algorithms.TemporalAnalysis.code_evolution_patterns/2
ElixirScope.Graph.Algorithms.MLAnalysis.predict_refactor_candidates/1

# 7. Performance optimization
ElixirScope.Graph.Performance.parallel_centrality/2
ElixirScope.Graph.Performance.incremental_updates/2
```

## Key Implementation Examples

### 1. libgraph Wrapper with Foundation Integration
```elixir
defmodule ElixirScope.Graph.Core do
  alias ElixirScope.Graph.FoundationIntegration
  
  @spec shortest_path_with_telemetry(Graph.t(), term(), term()) :: {:ok, [term()]} | {:error, :no_path}
  def shortest_path_with_telemetry(graph, source, target) do
    FoundationIntegration.measure_algorithm(:shortest_path, %{nodes: Graph.num_vertices(graph)}, fn ->
      case Graph.dijkstra(graph, source, target) do
        nil -> {:error, :no_path}
        path -> {:ok, path}
      end
    end)
  end
end
```

### 2. Custom Code Analysis Algorithm
```elixir
defmodule ElixirScope.Graph.Algorithms.CodeCentrality do
  @spec dependency_importance(Graph.t()) :: %{term() => float()}
  def dependency_importance(dependency_graph) do
    # Custom centrality measure for code dependencies
    # Combines betweenness centrality with dependency fan-out
    betweenness = Graph.centrality(dependency_graph, :betweenness)
    fan_out = calculate_dependency_fan_out(dependency_graph)
    
    # Weighted combination for code importance
    Map.merge(betweenness, fan_out, fn _k, b, f -> b * 0.7 + f * 0.3 end)
  end
end
```

### 3. AST to Graph Converter
```elixir
defmodule ElixirScope.Graph.Converters do
  @spec ast_to_dependency_graph(ElixirScope.AST.t()) :: Graph.t()
  def ast_to_dependency_graph(ast_data) do
    Graph.new(type: :directed)
    |> add_module_vertices(ast_data.modules)
    |> add_dependency_edges(ast_data.dependencies)
  end
end
```

## Foundation Integration

### Configuration Management
```elixir
# Graph algorithm parameters in Foundation config
%{
  graph: %{
    algorithms: %{
      pagerank: %{
        max_iterations: 100,
        damping_factor: 0.85,
        tolerance: 1.0e-6
      },
      community_detection: %{
        resolution: 1.0,
        randomness: 0.01
      }
    },
    performance: %{
      large_graph_threshold: 10000,
      parallel_processing: true
    }
  }
}
```

### Telemetry Integration
```elixir
defmodule ElixirScope.Graph.Algorithms.Centrality do
  def betweenness_centrality(graph) do
    Foundation.TelemetryService.measure(
      [:elixir_scope, :graph, :centrality, :betweenness],
      %{nodes: graph.nodes |> MapSet.size(), edges: graph.edges |> MapSet.size()},
      fn -> compute_betweenness_centrality(graph) end
    )
  end
end
```

### Performance Monitoring
```elixir
# Emit performance metrics for algorithm execution
Foundation.TelemetryService.emit_gauge(
  [:elixir_scope, :graph, :algorithm_duration],
  duration_ms,
  %{algorithm: :pagerank, nodes: node_count}
)
```

## Testing Strategy

### Unit Tests
```elixir
defmodule ElixirScope.Graph.Algorithms.PathfindingTest do
  use ExUnit.Case
  alias ElixirScope.Graph.{DataStructures, Algorithms.Pathfinding}
  
  test "shortest path in simple graph" do
    graph = DataStructures.new_graph([:a, :b, :c], [{:a, :b}, {:b, :c}])
    assert {:ok, [:a, :b, :c]} = Pathfinding.shortest_path(graph, :a, :c)
  end
  
  test "no path returns error" do
    graph = DataStructures.new_graph([:a, :b, :c], [{:a, :b}])
    assert {:error, :no_path} = Pathfinding.shortest_path(graph, :a, :c)
  end
end
```

### Property-Based Tests
```elixir
property "shortest path is optimal" do
  check all graph <- graph_generator(),
            {source, target} <- node_pair_generator(graph) do
    case Pathfinding.shortest_path(graph, source, target) do
      {:ok, path} ->
        # Verify path is valid and optimal
        assert valid_path?(graph, path)
        assert optimal_path?(graph, path, source, target)
      {:error, :no_path} ->
        # Verify no path exists
        assert not connected?(graph, source, target)
    end
  end
end
```

### Performance Benchmarks
```elixir
defmodule ElixirScope.Graph.BenchmarkTest do
  test "centrality algorithms scale appropriately" do
    graphs = [
      small_graph(100),    # 100 nodes
      medium_graph(1000),  # 1k nodes  
      large_graph(10000)   # 10k nodes
    ]
    
    Enum.each(graphs, fn graph ->
      {time_us, _result} = :timer.tc(fn ->
        Centrality.betweenness_centrality(graph)
      end)
      
      nodes = MapSet.size(graph.nodes)
      # Betweenness centrality should be O(V³) worst case
      assert time_us < nodes * nodes * nodes * 0.001  # 1µs per V³
    end)
  end
end
```

## Integration with Higher Layers

### CPG Layer Integration
```elixir
# CPG uses graph algorithms for dependency analysis
defmodule ElixirScope.CPG.Analysis do
  alias ElixirScope.Graph.Algorithms.{Pathfinding, Centrality}
  
  def analyze_dependencies(cpg) do
    dependency_graph = extract_dependency_graph(cpg)
    
    # Find critical functions using centrality
    centrality_scores = Centrality.betweenness_centrality(dependency_graph)
    
    # Identify dependency paths
    paths = find_dependency_paths(dependency_graph)
    
    %{centrality: centrality_scores, paths: paths}
  end
end
```

### Analysis Layer Integration
```elixir
# Analysis layer uses graph algorithms for architectural insights
defmodule ElixirScope.Analysis.Architectural do
  alias ElixirScope.Graph.Algorithms.{Community, Connectivity}
  
  def detect_module_clusters(module_graph) do
    # Use community detection to identify cohesive modules
    communities = Community.detect_communities(module_graph, resolution: 1.2)
    
    # Analyze connectivity between clusters
    inter_cluster_connections = analyze_connectivity(communities, module_graph)
    
    %{clusters: communities, connections: inter_cluster_connections}
  end
end
```

## libgraph Migration Strategy

### Dependency Addition
```elixir
# In mix.exs
defp deps do
  [
    {:foundation, "~> 0.1.0"},
    {:libgraph, "~> 0.16"},  # Add libgraph dependency
    # ... existing deps
  ]
end
```

### Implementation Approach
```bash
# 1. Create libgraph integration wrappers
lib/elixir_scope/graph/core.ex
lib/elixir_scope/graph/foundation_integration.ex

# 2. Add code-specific algorithm extensions
lib/elixir_scope/graph/algorithms/code_centrality.ex
lib/elixir_scope/graph/algorithms/dependency_analysis.ex

# 3. Create converters for ElixirScope data types
lib/elixir_scope/graph/converters.ex
```

### Reference Implementation Usage
```bash
# Reference code provides domain knowledge, not direct porting
docs/reference_implementation/graph/algorithms/ → Domain insights
docs/reference_implementation/graph/data_structures.ex → Type definitions

# Custom algorithms will be inspired by reference patterns
# but implemented using libgraph as the foundation
```

## Success Criteria

### Functional Requirements
- ✅ libgraph successfully integrated with Foundation services
- ✅ Core algorithms (shortest path, centrality, SCC) working via libgraph
- ✅ Custom code analysis algorithms implemented and tested
- ✅ AST/CPG to Graph converters functional
- ✅ >95% test coverage including libgraph integration tests

### Performance Targets (Revised for libgraph)
- **Small graphs** (100 nodes): All algorithms <5ms
- **Medium graphs** (1k nodes): Centrality algorithms <50ms  
- **Large graphs** (10k nodes): All algorithms <2 seconds
- **Memory usage**: <50MB for largest supported graphs (libgraph efficiency)

### Integration Verification
- CPG layer can consume graph analysis results
- Analysis layer can use community detection
- Foundation telemetry captures performance metrics
- Configuration management works for algorithm parameters

---

**Summary**: The hybrid libgraph approach provides a robust, efficient foundation for graph analysis in ElixirScope. By leveraging proven algorithms from libgraph and adding domain-specific extensions, we achieve faster implementation, lower maintenance burden, and better performance while maintaining full integration with the Foundation layer and ElixirScope architecture.