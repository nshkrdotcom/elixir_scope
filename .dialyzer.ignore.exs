[
  # Skeleton implementations - these modules only return :not_implemented
  # but are typed to return :ready | :not_implemented for future implementation
  {"lib/elixir_scope.ex", :contract_supertype, 66},
  {"lib/elixir_scope/analysis.ex", :extra_range, 12},
  {"lib/elixir_scope/ast.ex", :extra_range, 28},
  {"lib/elixir_scope/capture.ex", :extra_range, 12},
  {"lib/elixir_scope/cpg.ex", :extra_range, 12},
  {"lib/elixir_scope/debugger.ex", :extra_range, 12},
  {"lib/elixir_scope/graph.ex", :extra_range, 12},
  {"lib/elixir_scope/intelligence.ex", :extra_range, 12},
  {"lib/elixir_scope/query.ex", :extra_range, 12},

  # Graph layer: Defensive pattern matches for cycle detection
  # Dialyzer thinks Graph.topsort always returns list, but it can return false for cyclic graphs
  {"lib/elixir_scope/graph/core.ex", :pattern_match, 1},
  {"lib/elixir_scope/graph/algorithms/code_centrality.ex", :pattern_match, 1}
]
