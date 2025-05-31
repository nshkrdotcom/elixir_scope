# ORIG_FILE
defmodule ElixirScope.AST.Enhanced.DFGData do
  @moduledoc """
  Enhanced Data Flow Graph representation for Elixir code.

  Uses Static Single Assignment (SSA) form to handle Elixir's
  immutable variable semantics and pattern matching.
  """

  defstruct [
    # {module, function, arity}
    :function_key,
    # %{variable_name => [VariableVersion.t()]}
    :variables,
    # [Definition.t()] - Variable definitions
    :definitions,
    # [Use.t()] - Variable uses
    :uses,
    # [DataFlow.t()] - Data flow edges
    :data_flows,
    # [PhiNode.t()] - SSA merge points
    :phi_nodes,
    # %{scope_id => ScopeInfo.t()}
    :scopes,
    # Analysis results
    :analysis_results,
    # Additional metadata
    :metadata,

    # Additional fields expected by tests (for backward compatibility)
    # [DFGNode.t()] - Graph nodes as list
    :nodes,
    # [DFGEdge.t()] - Graph edges
    :edges,
    # %{node_id => DFGNode.t()} - Graph nodes as map for map_size
    :nodes_map,
    # [Mutation.t()] - Variable mutations/rebindings
    :mutations,
    # float() - Overall complexity score
    :complexity_score,
    # %{variable => lifetime_info} - Variable lifetimes
    :variable_lifetimes,
    # [VariableVersion.t()] - Unused variables
    :unused_variables,
    # [ShadowInfo.t()] - Variable shadowing
    :shadowed_variables,
    # [VariableVersion.t()] - Closure captures
    :captured_variables,
    # [OptimizationHint.t()] - Optimization opportunities
    :optimization_hints,
    # integer() - Variables with multiple inputs
    :fan_in,
    # integer() - Variables with multiple outputs
    :fan_out,
    # integer() - Dependency chain depth
    :depth,
    # integer() - Parallel data flows
    :width,
    # integer() - Overall data flow complexity
    :data_flow_complexity,
    # integer() - Variable interaction complexity
    :variable_complexity
  ]

  @type t :: %__MODULE__{
          function_key: {module(), atom(), non_neg_integer()},
          variables: %{String.t() => [VariableVersion.t()]},
          definitions: [Definition.t()],
          uses: [Use.t()],
          data_flows: [DataFlow.t()],
          phi_nodes: [PhiNode.t()],
          scopes: %{String.t() => ScopeInfo.t()},
          analysis_results: AnalysisResults.t(),
          metadata: map(),

          # Additional fields for test compatibility
          nodes: [DFGNode.t()],
          edges: [DFGEdge.t()],
          nodes_map: %{String.t() => DFGNode.t()},
          mutations: [Mutation.t()],
          complexity_score: float(),
          variable_lifetimes: %{String.t() => LifetimeInfo.t()},
          unused_variables: [VariableVersion.t()],
          shadowed_variables: [ShadowInfo.t()],
          captured_variables: [VariableVersion.t()],
          optimization_hints: [OptimizationHint.t()],
          fan_in: non_neg_integer(),
          fan_out: non_neg_integer(),
          depth: non_neg_integer(),
          width: non_neg_integer(),
          data_flow_complexity: non_neg_integer(),
          variable_complexity: non_neg_integer()
        }
end

defmodule ElixirScope.AST.Enhanced.VariableVersion do
  @moduledoc """
  Versioned variable in SSA form.

  Each variable assignment creates a new version.
  Example: x, x_1, x_2, etc.
  """

  defstruct [
    # Original variable name
    :name,
    # Version number (0, 1, 2, ...)
    :version,
    # SSA name (e.g., "x_1")
    :ssa_name,
    # Scope where defined
    :scope_id,
    # AST node where defined
    :definition_node,
    # Inferred type information
    :type_info,
    # Is this a function parameter?
    :is_parameter,
    # Is this variable captured in closure?
    :is_captured,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          version: non_neg_integer(),
          ssa_name: String.t(),
          scope_id: String.t(),
          definition_node: String.t(),
          type_info: TypeInfo.t() | nil,
          is_parameter: boolean(),
          is_captured: boolean(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.Definition do
  @moduledoc """
  Variable definition point in the data flow graph.
  """

  defstruct [
    # VariableVersion.t()
    :variable,
    # AST node where defined
    :ast_node_id,
    # Type of definition (see @definition_types)
    :definition_type,
    # AST of the defining expression
    :source_expression,
    # Source line number
    :line,
    # Scope identifier
    :scope_id,
    # [Definition.t()] - Definitions that reach here
    :reaching_definitions,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          variable: VariableVersion.t(),
          ast_node_id: String.t(),
          definition_type: atom(),
          source_expression: term(),
          line: non_neg_integer(),
          scope_id: String.t(),
          reaching_definitions: [t()],
          metadata: map()
        }

  @definition_types [
    # x = value
    :assignment,
    # Function parameter
    :parameter,
    # Pattern match in case/function head
    :pattern_match,
    # Variable in comprehension
    :comprehension,
    # Exception variable in catch/rescue
    :catch_variable,
    # Variable bound in receive
    :receive_variable
  ]

  def definition_types, do: @definition_types
end

defmodule ElixirScope.AST.Enhanced.Use do
  @moduledoc """
  Variable use point in the data flow graph.
  """

  defstruct [
    # VariableVersion.t()
    :variable,
    # AST node where used
    :ast_node_id,
    # Type of use (see @use_types)
    :use_type,
    # Usage context
    :context,
    # Source line number
    :line,
    # Scope identifier
    :scope_id,
    # Definition.t() that reaches this use
    :reaching_definition,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          variable: VariableVersion.t(),
          ast_node_id: String.t(),
          use_type: atom(),
          context: term(),
          line: non_neg_integer(),
          scope_id: String.t(),
          reaching_definition: Definition.t(),
          metadata: map()
        }

  @use_types [
    # Variable value read
    :read,
    # Variable used in pattern
    :pattern_match,
    # Variable used in guard
    :guard,
    # Variable passed to function
    :function_call,
    # Variable in pipe chain
    :pipe_operation,
    # Variable sent as message
    :message_send,
    # Variable captured in closure
    :closure_capture
  ]

  def use_types, do: @use_types
end

defmodule ElixirScope.AST.Enhanced.DataFlow do
  @moduledoc """
  Data flow edge connecting definition to use.
  """

  defstruct [
    # Definition.t()
    :from_definition,
    # Use.t()
    :to_use,
    # Type of data flow (see @flow_types)
    :flow_type,
    # Condition for this flow to occur
    :path_condition,
    # Flow probability (0.0-1.0)
    :probability,
    # Any transformation applied to data
    :transformation,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          from_definition: Definition.t(),
          to_use: Use.t(),
          flow_type: atom(),
          path_condition: term() | nil,
          probability: float(),
          transformation: term() | nil,
          metadata: map()
        }

  @flow_types [
    # Direct assignment flow
    :direct,
    # Flow through conditional
    :conditional,
    # Flow through pattern match
    :pattern_match,
    # Flow through pipe operation
    :pipe_transform,
    # Flow from function return
    :function_return,
    # Flow into closure
    :closure_capture,
    # Flow through message passing
    :message_pass,
    # Flow through destructuring assignment
    :destructuring
  ]

  def flow_types, do: @flow_types
end

defmodule ElixirScope.AST.Enhanced.PhiNode do
  @moduledoc """
  SSA Phi node for merging variable versions at control flow merge points.

  Example: After if-else, variables may have different versions
  that need to be merged.
  """

  defstruct [
    # VariableVersion.t() - Result of phi
    :target_variable,
    # [VariableVersion.t()] - Input versions
    :source_variables,
    # AST node ID where merge occurs
    :merge_point,
    # [condition] - Conditions for each source
    :conditions,
    # Scope where merge occurs
    :scope_id,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          target_variable: VariableVersion.t(),
          source_variables: [VariableVersion.t()],
          merge_point: String.t(),
          conditions: [term()],
          scope_id: String.t(),
          metadata: map()
        }
end

# ScopeInfo is defined in shared_data_structures.ex
alias ElixirScope.AST.Enhanced.ScopeInfo

defmodule ElixirScope.AST.Enhanced.AnalysisResults do
  @moduledoc """
  Results of data flow analysis.
  """

  defstruct [
    # %{variable => lifetime_info}
    :variable_lifetimes,
    # [VariableVersion.t()] - Unused variables
    :unused_variables,
    # [ShadowInfo.t()] - Variable shadowing
    :shadowed_variables,
    # [VariableVersion.t()] - Closure captures
    :captured_variables,
    # [OptimizationHint.t()] - Optimization opportunities
    :optimization_hints,
    # DataFlowComplexity.t() - Complexity metrics
    :complexity_metrics,
    # DependencyAnalysis.t() - Variable dependencies
    :dependency_analysis,
    # MutationAnalysis.t() - Mutation tracking
    :mutation_analysis,
    # PerformanceAnalysis.t() - Performance insights
    :performance_analysis
  ]

  @type t :: %__MODULE__{
          variable_lifetimes: %{String.t() => LifetimeInfo.t()},
          unused_variables: [VariableVersion.t()],
          shadowed_variables: [ShadowInfo.t()],
          captured_variables: [VariableVersion.t()],
          optimization_hints: [OptimizationHint.t()],
          complexity_metrics: DataFlowComplexity.t(),
          dependency_analysis: DependencyAnalysis.t(),
          mutation_analysis: MutationAnalysis.t(),
          performance_analysis: PerformanceAnalysis.t()
        }
end

defmodule ElixirScope.AST.Enhanced.TypeInfo do
  @moduledoc """
  Type information for variables (inferred or annotated).
  """

  defstruct [
    # Inferred or declared type
    :type,
    # Type constraints
    :constraints,
    # How type was determined
    :source,
    # Confidence level (0.0-1.0)
    :confidence,
    # Additional type metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          type: term(),
          constraints: [term()],
          source: atom(),
          confidence: float(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.ShadowInfo do
  @moduledoc """
  Information about variable shadowing.
  """

  defstruct [
    # VariableVersion.t() - Original variable
    :shadowed_variable,
    # VariableVersion.t() - Shadowing variable
    :shadowing_variable,
    # Where shadowing occurs
    :scope_context,
    # Risk of confusion
    :potential_confusion,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          shadowed_variable: VariableVersion.t(),
          shadowing_variable: VariableVersion.t(),
          scope_context: String.t(),
          potential_confusion: atom(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.OptimizationHint do
  @moduledoc """
  Optimization hints based on data flow analysis.
  """

  defstruct [
    # Type of optimization
    :type,
    # Human-readable description
    :description,
    # [VariableVersion.t()] - Affected variables
    :variables_involved,
    # Estimated benefit
    :potential_benefit,
    # Confidence in hint (0.0-1.0)
    :confidence,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          type: atom(),
          description: String.t(),
          variables_involved: [VariableVersion.t()],
          potential_benefit: atom(),
          confidence: float(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.DataFlowComplexity do
  @moduledoc """
  Data flow complexity metrics.
  """

  defstruct [
    # Total number of variables
    :variable_count,
    # Total number of definitions
    :definition_count,
    # Total number of uses
    :use_count,
    # Number of phi nodes
    :phi_node_count,
    # Maximum versions for any variable
    :max_variable_versions,
    # Maximum scope nesting depth
    :scope_depth,
    # Number of data flow edges
    :data_flow_edges,
    # Overall complexity score
    :complexity_score
  ]

  @type t :: %__MODULE__{
          variable_count: non_neg_integer(),
          definition_count: non_neg_integer(),
          use_count: non_neg_integer(),
          phi_node_count: non_neg_integer(),
          max_variable_versions: non_neg_integer(),
          scope_depth: non_neg_integer(),
          data_flow_edges: non_neg_integer(),
          complexity_score: float()
        }
end

defmodule ElixirScope.AST.Enhanced.DependencyAnalysis do
  @moduledoc """
  Variable dependency analysis results.
  """

  defstruct [
    # %{variable => [dependencies]}
    :dependency_graph,
    # [CircularDependency.t()]
    :circular_dependencies,
    # [DependencyChain.t()]
    :dependency_chains,
    # [VariableVersion.t()] - High-impact variables
    :critical_variables,
    # [VariableVersion.t()] - No dependencies
    :isolated_variables
  ]

  @type t :: %__MODULE__{
          dependency_graph: %{String.t() => [String.t()]},
          circular_dependencies: [CircularDependency.t()],
          dependency_chains: [DependencyChain.t()],
          critical_variables: [VariableVersion.t()],
          isolated_variables: [VariableVersion.t()]
        }
end

defmodule ElixirScope.AST.Enhanced.MutationAnalysis do
  @moduledoc """
  Analysis of variable mutations (rebinding in Elixir context).
  """

  defstruct [
    # [RebindingPoint.t()] - Where variables are rebound
    :rebinding_points,
    # %{variable => frequency}
    :mutation_frequency,
    # [MutationPattern.t()] - Common patterns
    :mutation_patterns,
    # [MutationIssue.t()] - Potential problems
    :potential_issues
  ]

  @type t :: %__MODULE__{
          rebinding_points: [RebindingPoint.t()],
          mutation_frequency: %{String.t() => non_neg_integer()},
          mutation_patterns: [MutationPattern.t()],
          potential_issues: [MutationIssue.t()]
        }
end

defmodule ElixirScope.AST.Enhanced.PerformanceAnalysis do
  @moduledoc """
  Performance analysis based on data flow patterns.
  """

  defstruct [
    # [MemoryPattern.t()] - Memory usage patterns
    :memory_usage_patterns,
    # [ComputationChain.t()] - Expensive computations
    :computation_chains,
    # [OptimizationOpportunity.t()]
    :optimization_opportunities,
    # [PerformanceRisk.t()] - Performance risks
    :performance_risks
  ]

  @type t :: %__MODULE__{
          memory_usage_patterns: [MemoryPattern.t()],
          computation_chains: [ComputationChain.t()],
          optimization_opportunities: [OptimizationOpportunity.t()],
          performance_risks: [PerformanceRisk.t()]
        }
end

# Supporting structures for analysis results
defmodule ElixirScope.AST.Enhanced.LifetimeInfo do
  defstruct [:start_line, :end_line, :scope_duration, :usage_frequency]

  @type t :: %__MODULE__{
          start_line: non_neg_integer(),
          end_line: non_neg_integer(),
          scope_duration: non_neg_integer(),
          usage_frequency: non_neg_integer()
        }
end

defmodule ElixirScope.AST.Enhanced.CircularDependency do
  defstruct [:variables, :cycle_length, :severity]
  @type t :: %__MODULE__{variables: [String.t()], cycle_length: non_neg_integer(), severity: atom()}
end

defmodule ElixirScope.AST.Enhanced.DependencyChain do
  defstruct [:variables, :chain_length, :complexity]

  @type t :: %__MODULE__{
          variables: [String.t()],
          chain_length: non_neg_integer(),
          complexity: float()
        }
end

defmodule ElixirScope.AST.Enhanced.RebindingPoint do
  defstruct [:variable, :old_version, :new_version, :ast_node_id, :reason]

  @type t :: %__MODULE__{
          variable: String.t(),
          old_version: VariableVersion.t(),
          new_version: VariableVersion.t(),
          ast_node_id: String.t(),
          reason: atom()
        }
end

defmodule ElixirScope.AST.Enhanced.MutationPattern do
  defstruct [:pattern_type, :frequency, :variables, :description]

  @type t :: %__MODULE__{
          pattern_type: atom(),
          frequency: non_neg_integer(),
          variables: [String.t()],
          description: String.t()
        }
end

defmodule ElixirScope.AST.Enhanced.MutationIssue do
  defstruct [:issue_type, :severity, :variables, :description, :suggestion]

  @type t :: %__MODULE__{
          issue_type: atom(),
          severity: atom(),
          variables: [String.t()],
          description: String.t(),
          suggestion: String.t()
        }
end

defmodule ElixirScope.AST.Enhanced.MemoryPattern do
  defstruct [:pattern_type, :variables, :estimated_impact, :description]

  @type t :: %__MODULE__{
          pattern_type: atom(),
          variables: [String.t()],
          estimated_impact: atom(),
          description: String.t()
        }
end

defmodule ElixirScope.AST.Enhanced.ComputationChain do
  defstruct [:variables, :operations, :estimated_cost, :optimization_potential]

  @type t :: %__MODULE__{
          variables: [String.t()],
          operations: [term()],
          estimated_cost: float(),
          optimization_potential: atom()
        }
end

defmodule ElixirScope.AST.Enhanced.OptimizationOpportunity do
  defstruct [
    :opportunity_type,
    :description,
    :variables,
    :estimated_benefit,
    :implementation_difficulty
  ]

  @type t :: %__MODULE__{
          opportunity_type: atom(),
          description: String.t(),
          variables: [String.t()],
          estimated_benefit: atom(),
          implementation_difficulty: atom()
        }
end

defmodule ElixirScope.AST.Enhanced.PerformanceRisk do
  defstruct [:risk_type, :severity, :variables, :description, :mitigation]

  @type t :: %__MODULE__{
          risk_type: atom(),
          severity: atom(),
          variables: [String.t()],
          description: String.t(),
          mitigation: String.t()
        }
end

# Additional structs expected by tests
defmodule ElixirScope.AST.Enhanced.DFGNode do
  @moduledoc """
  Node in the data flow graph representation expected by tests.
  """

  defstruct [
    # Unique node identifier
    :id,
    # Node type (:variable, :operation, :phi, :call, :pattern_match, :comprehension, etc.)
    :type,
    # Associated AST node ID
    :ast_node_id,
    # Associated variable (if applicable)
    :variable,
    # Operation type (if applicable)
    :operation,
    # Source line number
    :line,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          ast_node_id: String.t() | nil,
          variable: VariableVersion.t() | nil,
          operation: term() | nil,
          line: non_neg_integer() | nil,
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.DFGEdge do
  @moduledoc """
  Edge in the data flow graph representation expected by tests.
  """

  defstruct [
    # Unique edge identifier
    :id,
    # Edge type (:data_flow, :mutation, :conditional_flow, :call_flow, :pipe_flow, :capture, etc.)
    :type,
    # Source node ID
    :from_node,
    # Target node ID
    :to_node,
    # Edge label
    :label,
    # Condition for edge (if applicable)
    :condition,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          from_node: String.t(),
          to_node: String.t(),
          label: String.t() | nil,
          condition: term() | nil,
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.Mutation do
  @moduledoc """
  Variable mutation/rebinding information expected by tests.
  """

  defstruct [
    # Variable being mutated
    :variable,
    # Previous value/version
    :old_value,
    # New value/version
    :new_value,
    # AST node where mutation occurs
    :ast_node_id,
    # Type of mutation (:rebinding, :pattern_match, :assignment, etc.)
    :mutation_type,
    # Source line number
    :line,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          variable: String.t(),
          old_value: term(),
          new_value: term(),
          ast_node_id: String.t(),
          mutation_type: atom(),
          line: non_neg_integer() | nil,
          metadata: map()
        }
end
