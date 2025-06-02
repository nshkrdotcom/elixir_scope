# ORIG_FILE
defmodule ElixirScope.AST.Enhanced.CFGData do
  @moduledoc """
  Enhanced Control Flow Graph representation for Elixir code.

  Handles Elixir-specific constructs:
  - Pattern matching with multiple clauses
  - Guard clauses and compound conditions
  - Pipe operations and data flow
  - OTP behavior patterns
  """

  defstruct [
    # {module, function, arity}
    :function_key,
    # Entry node ID
    :entry_node,
    # List of exit node IDs (multiple returns)
    :exit_nodes,
    # %{node_id => CFGNode.t()}
    :nodes,
    # [CFGEdge.t()]
    :edges,
    # %{scope_id => ScopeInfo.t()}
    :scopes,
    # ComplexityMetrics.t()
    :complexity_metrics,
    # PathAnalysis.t()
    :path_analysis,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          function_key: {module(), atom(), non_neg_integer()},
          entry_node: String.t(),
          exit_nodes: [String.t()],
          nodes: %{String.t() => CFGNode.t()},
          edges: [CFGEdge.t()],
          scopes: %{String.t() => ScopeInfo.t()},
          complexity_metrics: ComplexityMetrics.t(),
          path_analysis: PathAnalysis.t(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.CFGNode do
  @moduledoc """
  Individual node in the Control Flow Graph.
  """

  defstruct [
    # Unique node identifier
    :id,
    # Node type (see @node_types)
    :type,
    # Corresponding AST node ID
    :ast_node_id,
    # Source line number
    :line,
    # Scope identifier
    :scope_id,
    # AST expression for this node
    :expression,
    # [node_id] - incoming edges
    :predecessors,
    # [node_id] - outgoing edges
    :successors,
    # Node-specific metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          ast_node_id: String.t() | nil,
          line: non_neg_integer(),
          scope_id: String.t(),
          expression: term(),
          predecessors: [String.t()],
          successors: [String.t()],
          metadata: map()
        }

  # Elixir-specific node types
  @node_types [
    # Basic control flow
    :entry,
    :exit,
    :statement,
    :expression,

    # Pattern matching
    :pattern_match,
    :case_entry,
    :case_clause,
    :guard_check,

    # Function calls and operations
    :function_call,
    :pipe_operation,
    :anonymous_function,

    # Control structures
    :if_condition,
    :if_then,
    :if_else,
    :cond_entry,
    :cond_clause,
    :try_entry,
    :catch_clause,
    :rescue_clause,
    :after_clause,

    # Comprehensions
    :comprehension_entry,
    :comprehension_filter,
    :comprehension_generator,

    # Process operations
    :send_message,
    :receive_message,
    :spawn_process
  ]

  def node_types, do: @node_types
end

defmodule ElixirScope.AST.Enhanced.CFGEdge do
  @moduledoc """
  Edge in the Control Flow Graph representing control flow transitions.
  """

  defstruct [
    # Source node
    :from_node_id,
    # Target node
    :to_node_id,
    # Edge type (see @edge_types)
    :type,
    # Optional condition (for conditional edges)
    :condition,
    # Execution probability (0.0-1.0)
    :probability,
    # Edge-specific metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          from_node_id: String.t(),
          to_node_id: String.t(),
          type: atom(),
          condition: term() | nil,
          probability: float(),
          metadata: map()
        }

  @edge_types [
    # Normal sequential execution
    :sequential,
    # If/case branch
    :conditional,
    # Pattern match success
    :pattern_match,
    # Pattern match failure (fall through)
    :pattern_no_match,
    # Guard clause success
    :guard_success,
    # Guard clause failure
    :guard_failure,
    # Exception flow
    :exception,
    # Exception caught
    :catch,
    # Loop iteration
    :loop_back,
    # Loop termination
    :loop_exit
  ]

  def edge_types, do: @edge_types
end

# ComplexityMetrics is defined in shared_data_structures.ex
# alias ElixirScope.AST.Enhanced.ComplexityMetrics

defmodule ElixirScope.AST.Enhanced.PathAnalysis do
  @moduledoc """
  Path analysis results for control flow graph.
  """

  defstruct [
    # [Path.t()] - All execution paths
    :all_paths,
    # [Path.t()] - Longest/most complex paths
    :critical_paths,
    # [node_id] - Unreachable nodes
    :unreachable_nodes,
    # LoopAnalysis.t() - Loop detection results
    :loop_analysis,
    # BranchCoverage.t() - Branch coverage analysis
    :branch_coverage,
    # %{path_id => condition} - Path conditions
    :path_conditions
  ]

  @type t :: %__MODULE__{
          all_paths: [Path.t()],
          critical_paths: [Path.t()],
          unreachable_nodes: [String.t()],
          loop_analysis: LoopAnalysis.t(),
          branch_coverage: BranchCoverage.t(),
          path_conditions: %{String.t() => term()}
        }
end

defmodule ElixirScope.AST.Enhanced.Path do
  @moduledoc """
  Represents an execution path through the CFG.
  """

  defstruct [
    # Unique path identifier
    :id,
    # [node_id] - Nodes in path
    :nodes,
    # [edge] - Edges in path
    :edges,
    # [condition] - Conditions for this path
    :conditions,
    # Path complexity score
    :complexity,
    # Execution probability
    :probability,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          nodes: [String.t()],
          edges: [CFGEdge.t()],
          conditions: [term()],
          complexity: non_neg_integer(),
          probability: float(),
          metadata: map()
        }
end

# ScopeInfo is defined in shared_data_structures.ex
# alias ElixirScope.AST.Enhanced.ScopeInfo

defmodule ElixirScope.AST.Enhanced.LoopAnalysis do
  @moduledoc """
  Loop detection and analysis results.
  """

  defstruct [
    # [Loop.t()] - Detected loops
    :loops,
    # Maximum loop nesting depth
    :loop_nesting_depth,
    # Risk of infinite loops
    :infinite_loop_risk,
    # Complexity added by loops
    :loop_complexity
  ]

  @type t :: %__MODULE__{
          loops: [Loop.t()],
          loop_nesting_depth: non_neg_integer(),
          infinite_loop_risk: atom(),
          loop_complexity: non_neg_integer()
        }
end

defmodule ElixirScope.AST.Enhanced.Loop do
  @moduledoc """
  Represents a detected loop in the CFG.
  """

  defstruct [
    # Unique loop identifier
    :id,
    # Loop header node
    :header_node,
    # [edge] - Back edges
    :back_edges,
    # [node_id] - Nodes in loop body
    :body_nodes,
    # [condition] - Loop exit conditions
    :exit_conditions,
    # Nesting level
    :nesting_level,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          header_node: String.t(),
          back_edges: [CFGEdge.t()],
          body_nodes: [String.t()],
          exit_conditions: [term()],
          nesting_level: non_neg_integer(),
          metadata: map()
        }
end

defmodule ElixirScope.AST.Enhanced.BranchCoverage do
  @moduledoc """
  Branch coverage analysis for testing.
  """

  defstruct [
    # Total number of branches
    :total_branches,
    # Number of covered branches
    :covered_branches,
    # [branch] - Uncovered branches
    :uncovered_branches,
    # Coverage percentage
    :coverage_percentage,
    # [branch] - Critical uncovered branches
    :critical_uncovered
  ]

  @type t :: %__MODULE__{
          total_branches: non_neg_integer(),
          covered_branches: non_neg_integer(),
          uncovered_branches: [term()],
          coverage_percentage: float(),
          critical_uncovered: [term()]
        }
end
