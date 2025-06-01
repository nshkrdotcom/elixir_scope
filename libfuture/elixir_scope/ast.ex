defmodule ElixirScope.AST do
  @moduledoc """
  Layer 2: AST Operations and Repository
  
  Coordinates between:
  - Parsing: Extract and analyze AST
  - Data: Define what we store
  - Repository: How we store and retrieve
  - Transformation: Modify AST for instrumentation
  - Compilation: Build system integration
  - Querying: How we search stored data
  - Analysis: Pattern detection and optimization
  """
  
  # Main entry points for the AST layer
  defdelegate parse(source), to: ElixirScope.AST.Parsing.Parser
  defdelegate store_module(data), to: ElixirScope.AST.Repository.Enhanced
  defdelegate transform(ast, plan), to: ElixirScope.AST.Transformation.Transformer
  defdelegate find_patterns(criteria), to: ElixirScope.AST.Analysis.PatternMatcher.Core
end
