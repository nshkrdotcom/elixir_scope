# ORIG_FILE
defmodule ElixirScope.AST.Enhanced.SharedDataStructures do
  @moduledoc """
  Shared data structures used across CFG, DFG, and CPG components.

  This module contains common structures to avoid duplication and ensure consistency.
  """

  # Re-export all shared structures
  defdelegate scope_types(), to: ScopeInfo
  defdelegate complexity_metrics_fields(), to: ComplexityMetrics
end

defmodule ElixirScope.AST.Enhanced.ScopeInfo do
  @moduledoc """
  Information about variable scopes in Elixir.
  Shared between CFG and DFG analysis.
  """

  defstruct [
    # Unique scope identifier
    :id,
    # Scope type (see @scope_types)
    :type,
    # Parent scope ID
    :parent_scope,
    # [scope_id] - Child scopes
    :child_scopes,
    # [variable_name] - Variables in scope (CFG) or [VariableVersion.t()] (DFG)
    :variables,
    # AST node that creates this scope
    :ast_node_id,
    # [ast_node_id] - Ways to enter scope
    :entry_points,
    # [ast_node_id] - Ways to exit scope
    :exit_points,
    # Additional metadata
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          parent_scope: String.t() | nil,
          child_scopes: [String.t()],
          # Flexible to handle both CFG and DFG usage
          variables: [String.t()] | [term()],
          ast_node_id: String.t(),
          entry_points: [String.t()],
          exit_points: [String.t()],
          metadata: map()
        }

  @scope_types [
    # Function scope
    :function,
    # Case clause scope
    :case_clause,
    # If/else branch scope
    :if_branch,
    # Try block scope
    :try_block,
    # Catch/rescue clause scope
    :catch_clause,
    # Comprehension scope
    :comprehension,
    # Receive clause scope
    :receive_clause,
    # Anonymous function scope
    :anonymous_function,
    # Module scope
    :module
  ]

  def scope_types, do: @scope_types
end

# ComplexityMetrics is defined in complexity_metrics.ex
# We just re-export it here for convenience
alias ElixirScope.AST.Enhanced.ComplexityMetrics
