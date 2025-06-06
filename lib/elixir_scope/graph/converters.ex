defmodule ElixirScope.Graph.Converters do
  @moduledoc """
  Converters for transforming AST and CPG data structures into libgraph structures.

  This module provides utilities to convert ElixirScope's AST and CPG data structures
  into libgraph-compatible graphs for analysis and algorithm execution.
  """

  alias ElixirScope.Graph.FoundationIntegration

  @type ast_data :: %{
          :modules => [term()],
          :dependencies => [{term(), term()}],
          :functions => [term()]
        }
  @type cpg_data :: %{:nodes => [term()], :edges => [{term(), term(), map()}], :metadata => map()}
  @type graph :: Graph.t()

  @doc """
  Convert AST dependency data to a libgraph structure.

  Creates a directed graph where modules are vertices and dependencies are edges.
  Useful for analyzing module-level dependencies and import relationships.

  ## Examples

      iex> ast_data = %{modules: [:a, :b], dependencies: [{:a, :b}]}
      iex> graph = ElixirScope.Graph.Converters.ast_to_dependency_graph(ast_data)
      iex> Graph.vertices(graph)
      [:a, :b]

      iex> Graph.edges(graph)
      [%Graph.Edge{v1: :a, v2: :b, weight: 1}]
  """
  @spec ast_to_dependency_graph(ast_data()) :: graph()
  def ast_to_dependency_graph(ast_data) do
    FoundationIntegration.measure_algorithm(
      :ast_to_graph_conversion,
      %{
        modules: length(Map.get(ast_data, :modules, [])),
        dependencies: length(Map.get(ast_data, :dependencies, []))
      },
      fn ->
        graph = Graph.new(type: :directed)

        graph
        |> add_module_vertices(Map.get(ast_data, :modules, []))
        |> add_dependency_edges(Map.get(ast_data, :dependencies, []))
      end
    )
  end

  @doc """
  Convert AST function call data to a call graph.

  Creates a directed graph representing function call relationships.
  Useful for analyzing function dependencies and call patterns.

  ## Examples

      iex> ast_data = %{functions: [:f1, :f2], calls: [{:f1, :f2}]}
      iex> graph = ElixirScope.Graph.Converters.ast_to_call_graph(ast_data)
      iex> Graph.vertices(graph)
      [:f1, :f2]
  """
  @spec ast_to_call_graph(ast_data()) :: graph()
  def ast_to_call_graph(ast_data) do
    FoundationIntegration.measure_algorithm(
      :ast_to_call_graph_conversion,
      %{
        functions: length(Map.get(ast_data, :functions, [])),
        calls: length(Map.get(ast_data, :calls, []))
      },
      fn ->
        graph = Graph.new(type: :directed)

        graph
        |> add_function_vertices(Map.get(ast_data, :functions, []))
        |> add_call_edges(Map.get(ast_data, :calls, []))
      end
    )
  end

  @doc """
  Convert CPG data to a comprehensive analysis graph.

  Creates a graph from Code Property Graph data with rich metadata on edges.
  Supports weighted edges and node/edge attributes for advanced analysis.

  ## Examples

      iex> cpg_data = %{nodes: [:n1, :n2], edges: [{:n1, :n2, %{type: :control_flow}}]}
      iex> graph = ElixirScope.Graph.Converters.cpg_to_analysis_graph(cpg_data)
      iex> Graph.vertices(graph)
      [:n1, :n2]
  """
  @spec cpg_to_analysis_graph(cpg_data()) :: graph()
  def cpg_to_analysis_graph(cpg_data) do
    FoundationIntegration.measure_algorithm(
      :cpg_to_graph_conversion,
      %{
        nodes: length(Map.get(cpg_data, :nodes, [])),
        edges: length(Map.get(cpg_data, :edges, []))
      },
      fn ->
        graph = Graph.new(type: :directed)

        graph
        |> add_cpg_vertices(Map.get(cpg_data, :nodes, []))
        |> add_cpg_edges(Map.get(cpg_data, :edges, []))
      end
    )
  end

  @doc """
  Convert a generic data structure with nodes and edges to a graph.

  Flexible converter for any data structure that has nodes and edges.
  Useful for testing and custom data structure conversion.

  ## Examples

      iex> data = %{vertices: [:a, :b], edges: [{:a, :b}]}
      iex> graph = ElixirScope.Graph.Converters.generic_to_graph(data, :vertices, :edges)
      iex> Graph.vertices(graph)
      [:a, :b]
  """
  @spec generic_to_graph(map(), atom(), atom()) :: graph()
  def generic_to_graph(data, vertex_key, edge_key) do
    FoundationIntegration.measure_algorithm(
      :generic_to_graph_conversion,
      %{
        vertices: length(Map.get(data, vertex_key, [])),
        edges: length(Map.get(data, edge_key, []))
      },
      fn ->
        graph = Graph.new(type: :directed)

        graph
        |> add_vertices(Map.get(data, vertex_key, []))
        |> add_edges(Map.get(data, edge_key, []))
      end
    )
  end

  @doc """
  Extract dependency subgraph from a larger graph.

  Creates a subgraph containing only nodes that are part of dependency chains
  between specified source and target nodes.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> subgraph = ElixirScope.Graph.Converters.extract_dependency_subgraph(graph, [:a], [:b])
      iex> Graph.vertices(subgraph)
      [:a, :b]
  """
  @spec extract_dependency_subgraph(graph(), [term()], [term()]) :: graph()
  def extract_dependency_subgraph(graph, source_nodes, target_nodes) do
    FoundationIntegration.measure_algorithm(
      :dependency_subgraph_extraction,
      %{
        total_nodes: Graph.num_vertices(graph),
        source_nodes: length(source_nodes),
        target_nodes: length(target_nodes)
      },
      fn ->
        # Find all nodes that are part of paths between sources and targets
        relevant_nodes = find_relevant_nodes(graph, source_nodes, target_nodes)

        # Create subgraph with only relevant nodes and their edges
        Graph.subgraph(graph, relevant_nodes)
      end
    )
  end

  # Private helper functions

  @spec add_module_vertices(graph(), [term()]) :: graph()
  defp add_module_vertices(graph, modules) do
    Enum.reduce(modules, graph, fn module, acc ->
      Graph.add_vertex(acc, module)
    end)
  end

  @spec add_dependency_edges(graph(), [{term(), term()}]) :: graph()
  defp add_dependency_edges(graph, dependencies) do
    Enum.reduce(dependencies, graph, fn {from, to}, acc ->
      Graph.add_edge(acc, from, to, weight: 1)
    end)
  end

  @spec add_function_vertices(graph(), [term()]) :: graph()
  defp add_function_vertices(graph, functions) do
    Enum.reduce(functions, graph, fn function, acc ->
      Graph.add_vertex(acc, function)
    end)
  end

  @spec add_call_edges(graph(), [{term(), term()}]) :: graph()
  defp add_call_edges(graph, calls) do
    Enum.reduce(calls, graph, fn {caller, callee}, acc ->
      # Add weight based on call frequency if available, default to 1
      Graph.add_edge(acc, caller, callee, weight: 1)
    end)
  end

  @spec add_cpg_vertices(graph(), [term()]) :: graph()
  defp add_cpg_vertices(graph, nodes) do
    Enum.reduce(nodes, graph, fn node, acc ->
      Graph.add_vertex(acc, node)
    end)
  end

  @spec add_cpg_edges(graph(), [{term(), term(), map()}]) :: graph()
  defp add_cpg_edges(graph, edges) do
    Enum.reduce(edges, graph, fn {from, to, metadata}, acc ->
      weight = Map.get(metadata, :weight, 1)
      Graph.add_edge(acc, from, to, weight: weight)
    end)
  end

  @spec add_vertices(graph(), [term()]) :: graph()
  defp add_vertices(graph, vertices) do
    Enum.reduce(vertices, graph, fn vertex, acc ->
      Graph.add_vertex(acc, vertex)
    end)
  end

  @spec add_edges(graph(), [{term(), term()}]) :: graph()
  defp add_edges(graph, edges) do
    Enum.reduce(edges, graph, fn {from, to}, acc ->
      Graph.add_edge(acc, from, to, weight: 1)
    end)
  end

  @spec find_relevant_nodes(graph(), [term()], [term()]) :: [term()]
  defp find_relevant_nodes(graph, source_nodes, target_nodes) do
    # Find all nodes reachable from sources
    reachable_from_sources = find_reachable_nodes(graph, source_nodes)

    # Find all nodes that can reach targets (reverse graph)
    reverse_graph = Graph.transpose(graph)
    can_reach_targets = find_reachable_nodes(reverse_graph, target_nodes)

    # Intersection gives us nodes that are on paths from sources to targets
    MapSet.intersection(
      MapSet.new(reachable_from_sources),
      MapSet.new(can_reach_targets)
    )
    |> MapSet.to_list()
  end

  @spec find_reachable_nodes(graph(), [term()]) :: [term()]
  defp find_reachable_nodes(graph, start_nodes) do
    Enum.reduce(start_nodes, MapSet.new(), fn node, acc ->
      reachable = Graph.reachable(graph, [node])
      MapSet.union(acc, MapSet.new(reachable))
    end)
    |> MapSet.to_list()
  end
end
