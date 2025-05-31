# # ORIG_FILE
# defmodule ElixirScope.MigrationHelpers do
#   @moduledoc """
#   Helper functions for migrating to the new 9-layer architecture.

#   This module provides compatibility functions and migration utilities
#   to help transition from the old structure to the new layered architecture.
#   """

#   # Old module aliases for backward compatibility
#   # alias ElixirScope.AST.Repository.Enhanced, as: EnhancedRepository
#   # alias ElixirScope.CPG.Builder, as: CPGBuilder
#   # alias ElixirScope.Graph.Algorithms.Centrality, as: CPGMath
#   # alias ElixirScope.Capture.Runtime.Runtime, as: RuntimeCapture
#   # alias ElixirScope.Intelligence.AI, as: AIBridge

#   @doc """
#   Migrate old CPGMath calls to new Graph.Algorithms.

#   This function helps identify where old CPGMath calls need to be updated.
#   """
#   def migrate_cpg_math_calls do
#     IO.warn("""
#     CPGMath module has been moved to ElixirScope.Graph.Algorithms.
#     Please update your calls:

#     Old: ElixirScope.Analysis.ASTRepository.Enhanced.CPGMath.centrality(...)
#     New: ElixirScope.Graph.Algorithms.Centrality.calculate(...)
#     """)
#     :ok
#   end

#   @doc """
#   Migrate old enhanced repository calls.
#   """
#   def migrate_enhanced_repository_calls do
#     IO.warn("""
#     Enhanced repository has been reorganized:

#     Old: ElixirScope.AST.Enhanced
#     New: ElixirScope.AST.Repository.Enhanced
#     """)
#     :ok
#   end

#   @doc """
#   Get mapping of old modules to new modules.
#   """
#   def get_module_mapping do
#     %{
#       "ElixirScope.AST.Enhanced.CPGMath" => "ElixirScope.Graph.Algorithms",
#       "ElixirScope.AST.Enhanced.CPGBuilder" => "ElixirScope.CPG.Builder",
#       "ElixirScope.AST.Enhanced.CPGSemantics" => "ElixirScope.CPG.Semantics",
#       "ElixirScope.AST.Enhanced" => "ElixirScope.AST.Enhanced",
#       "ElixirScope.AI" => "ElixirScope.Intelligence.AI",
#       "ElixirScope.Capture" => "ElixirScope.Capture.Runtime.Runtime",
#       "ElixirScope.Query.Legacy" => "ElixirScope.Query.Legacy"
#     }
#   end
# end
