# ORIG_FILE
defmodule ElixirScope.AST.Enhanced.CPGData do
  @moduledoc """
  Code Property Graph (CPG) that unifies AST, CFG, and DFG representations.

  A CPG provides a unified view of code structure by combining:
  - Syntax (AST): What the code looks like
  - Control Flow (CFG): How execution flows
  - Data Flow (DFG): How data moves through the code

  This enables powerful queries that span multiple dimensions of code analysis.
  """

  alias ElixirScope.AST.Enhanced.{CFGData, DFGData, OptimizationHint}

  defstruct [
    # {module, function, arity}
    :function_key,
    # %{node_id => CPGNode.t()}
    :nodes,
    # [CPGEdge.t()]
    :edges,
    # Cross-references between AST/CFG/DFG nodes
    :node_mappings,
    # Optimized indexes for common queries
    :query_indexes,
    # %{:cfg => CFGData.t(), :dfg => DFGData.t()}
    :source_graphs,
    # UnifiedAnalysis.t() - Cross-cutting analysis
    :unified_analysis,
    # Additional metadata
    :metadata,
    # Test compatibility fields
    # Direct reference to CFG
    :control_flow_graph,
    # Direct reference to DFG
    :data_flow_graph,
    # Unified nodes map
    :unified_nodes,
    # Unified edges list
    :unified_edges,
    # Complexity analysis
    :complexity_metrics,
    # Path analysis
    :path_sensitive_analysis,
    # Security analysis
    :security_analysis,
    # Alias analysis
    :alias_analysis,
    # Performance analysis
    :performance_analysis,
    # Information flow analysis
    :information_flow_analysis,
    # Code quality analysis
    :code_quality_analysis
  ]

  @type t :: %__MODULE__{
          function_key: {module(), atom(), non_neg_integer()},
          nodes: %{String.t() => CPGNode.t()},
          edges: [CPGEdge.t()],
          node_mappings: NodeMappings.t(),
          query_indexes: QueryIndexes.t(),
          source_graphs: %{atom() => term()},
          unified_analysis: UnifiedAnalysis.t(),
          metadata: map(),
          # Test compatibility fields
          control_flow_graph: term(),
          data_flow_graph: term(),
          unified_nodes: term(),
          unified_edges: term(),
          complexity_metrics: term(),
          path_sensitive_analysis: term(),
          security_analysis: term(),
          alias_analysis: term(),
          performance_analysis: term(),
          information_flow_analysis: term(),
          code_quality_analysis: term()
        }
end

defmodule ElixirScope.AST.Enhanced.CPGNode do
  @moduledoc """
  Unified node in the Code Property Graph.

  Combines information from AST, CFG, and DFG representations.
  """

  defstruct [
    # Unique node identifier
    :id,
    # Node type (:unified, :cfg_only, :dfg_only)
    :type,
    # Reference to AST node
    :ast_node_id,
    # Reference to CFG node
    :cfg_node_id,
    # Reference to DFG node
    :dfg_node_id,
    # Source line number
    :line,
    # Scope identifier
    :scope_id,
    # AST expression
    :expression,
    # Control flow specific data
    :control_flow_info,
    # Data flow specific data
    :data_flow_info,
    # Properties derived from unification
    :unified_properties,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          ast_node_id: String.t() | nil,
          cfg_node_id: String.t() | nil,
          dfg_node_id: String.t() | nil,
          line: non_neg_integer(),
          scope_id: String.t(),
          expression: term(),
          control_flow_info: map(),
          data_flow_info: map(),
          unified_properties: map(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.CPGEdge do
  @moduledoc """
  Unified edge in the Code Property Graph.

  Represents relationships between nodes across different graph dimensions.
  """

  defstruct [
    # Unique edge identifier
    :id,
    # Source node
    :from_node_id,
    # Target node
    :to_node_id,
    # Edge type (:control_flow, :data_flow, :unified)
    :type,
    # Edge subtype (specific to graph type)
    :subtype,
    # Optional condition
    :condition,
    # Edge probability
    :probability,
    # Which graph this edge comes from
    :source_graph,
    # Properties derived from unification
    :unified_properties,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          from_node_id: String.t(),
          to_node_id: String.t(),
          type: atom(),
          subtype: atom(),
          condition: term() | nil,
          probability: float(),
          source_graph: atom(),
          unified_properties: map(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.NodeMappings do
  @moduledoc """
  Cross-references between AST, CFG, and DFG nodes.
  """

  defstruct [
    # %{ast_node_id => [cfg_node_id]}
    :ast_to_cfg,
    # %{ast_node_id => [dfg_node_id]}
    :ast_to_dfg,
    # %{cfg_node_id => [dfg_node_id]}
    :cfg_to_dfg,
    # %{dfg_node_id => [cfg_node_id]}
    :dfg_to_cfg,
    # %{unified_node_id => %{ast: id, cfg: id, dfg: id}}
    :unified_mappings,
    # Reverse lookup tables
    :reverse_mappings
  ]

  @type t :: %__MODULE__{
          ast_to_cfg: %{String.t() => [String.t()]},
          ast_to_dfg: %{String.t() => [String.t()]},
          cfg_to_dfg: %{String.t() => [String.t()]},
          dfg_to_cfg: %{String.t() => [String.t()]},
          unified_mappings: %{String.t() => map()},
          reverse_mappings: map()
        }
end

defmodule ElixirScope.AST.Enhanced.QueryIndexes do
  @moduledoc """
  Optimized indexes for common CPG queries.
  """

  defstruct [
    # %{node_type => [node_id]}
    :by_type,
    # %{line_number => [node_id]}
    :by_line,
    # %{scope_id => [node_id]}
    :by_scope,
    # %{variable_name => [node_id]}
    :by_variable,
    # %{function_name => [node_id]}
    :by_function_call,
    # Precomputed control flow paths
    :control_flow_paths,
    # Precomputed data flow chains
    :data_flow_chains,
    # Indexes for common patterns
    :pattern_indexes
  ]

  @type t :: %__MODULE__{
          by_type: %{atom() => [String.t()]},
          by_line: %{non_neg_integer() => [String.t()]},
          by_scope: %{String.t() => [String.t()]},
          by_variable: %{String.t() => [String.t()]},
          by_function_call: %{String.t() => [String.t()]},
          control_flow_paths: map(),
          data_flow_chains: map(),
          pattern_indexes: map()
        }
end

defmodule ElixirScope.AST.Enhanced.UnifiedAnalysis do
  @moduledoc """
  Cross-cutting analysis results that span multiple graph dimensions.
  """

  defstruct [
    # SecurityAnalysis.t() - Security vulnerabilities
    :security_analysis,
    # PerformanceAnalysis.t() - Performance issues
    :performance_analysis,
    # QualityAnalysis.t() - Code quality metrics
    :quality_analysis,
    # ComplexityAnalysis.t() - Unified complexity
    :complexity_analysis,
    # PatternAnalysis.t() - Code patterns
    :pattern_analysis,
    # DependencyAnalysis.t() - Dependencies
    :dependency_analysis,
    # InformationFlow.t() - Information flow tracking
    :information_flow,
    # AliasAnalysis.t() - Alias analysis
    :alias_analysis,
    # [OptimizationHint.t()] - Optimization opportunities
    :optimization_hints
  ]

  @type t :: %__MODULE__{
          security_analysis: SecurityAnalysis.t(),
          performance_analysis: PerformanceAnalysis.t(),
          quality_analysis: QualityAnalysis.t(),
          complexity_analysis: ComplexityAnalysis.t(),
          pattern_analysis: PatternAnalysis.t(),
          dependency_analysis: DependencyAnalysis.t(),
          information_flow: InformationFlow.t(),
          alias_analysis: AliasAnalysis.t(),
          optimization_hints: [OptimizationHint.t()]
        }
end

# Supporting analysis structures
defmodule ElixirScope.AST.Enhanced.SecurityAnalysis do
  defstruct [:vulnerabilities, :risk_level, :security_patterns, :recommendations]

  @type t :: %__MODULE__{
          vulnerabilities: [map()],
          risk_level: atom(),
          security_patterns: [map()],
          recommendations: [String.t()]
        }
end

defmodule ElixirScope.AST.Enhanced.PerformanceAnalysis do
  defstruct [:bottlenecks, :optimization_opportunities, :performance_risks, :metrics]

  @type t :: %__MODULE__{
          bottlenecks: [map()],
          optimization_opportunities: [map()],
          performance_risks: [map()],
          metrics: map()
        }
end

defmodule ElixirScope.AST.Enhanced.QualityAnalysis do
  defstruct [:code_smells, :maintainability_score, :readability_score, :quality_metrics]

  @type t :: %__MODULE__{
          code_smells: [map()],
          maintainability_score: float(),
          readability_score: float(),
          quality_metrics: map()
        }
end

defmodule ElixirScope.AST.Enhanced.ComplexityAnalysis do
  defstruct [:unified_complexity, :complexity_distribution, :hotspots, :trends]

  @type t :: %__MODULE__{
          unified_complexity: float(),
          complexity_distribution: map(),
          hotspots: [map()],
          trends: map()
        }
end

defmodule ElixirScope.AST.Enhanced.PatternAnalysis do
  defstruct [:detected_patterns, :anti_patterns, :design_patterns, :pattern_metrics]

  @type t :: %__MODULE__{
          detected_patterns: [map()],
          anti_patterns: [map()],
          design_patterns: [map()],
          pattern_metrics: map()
        }
end

defmodule ElixirScope.AST.Enhanced.InformationFlow do
  defstruct [:flow_paths, :sensitive_flows, :flow_violations, :flow_metrics]

  @type t :: %__MODULE__{
          flow_paths: [map()],
          sensitive_flows: [map()],
          flow_violations: [map()],
          flow_metrics: map()
        }
end

defmodule ElixirScope.AST.Enhanced.AliasAnalysis do
  defstruct [:aliases, :alias_chains, :alias_conflicts, :alias_metrics]

  @type t :: %__MODULE__{
          aliases: [map()],
          alias_chains: [map()],
          alias_conflicts: [map()],
          alias_metrics: map()
        }
end
