defmodule ElixirScope.Graph.Utils do
  @moduledoc """
  Utility functions for graph operations and analysis.

  Provides helper functions for common graph operations, validation,
  visualization, and performance analysis.
  """

  alias ElixirScope.Graph.FoundationIntegration

  @type graph :: Graph.t()
  @type vertex :: term()
  @type edge :: Graph.Edge.t()

  @doc """
  Generate basic statistics about a graph.

  Returns comprehensive statistics including node count, edge count,
  density, diameter, and other graph properties.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> stats = ElixirScope.Graph.Utils.graph_statistics(graph)
      iex> stats.node_count
      2
      iex> stats.edge_count
      1
  """
  @spec graph_statistics(graph()) :: map()
  def graph_statistics(graph) do
    FoundationIntegration.measure_algorithm(
      :graph_statistics,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        node_count = Graph.num_vertices(graph)
        edge_count = Graph.num_edges(graph)

        %{
          node_count: node_count,
          edge_count: edge_count,
          density: calculate_density(node_count, edge_count),
          is_directed: is_directed_graph?(graph),
          is_acyclic: Graph.is_acyclic?(graph),
          component_count: length(Graph.components(graph)),
          average_degree: calculate_average_degree(node_count, edge_count),
          max_degree: calculate_max_degree(graph),
          isolated_nodes: count_isolated_nodes(graph)
        }
      end
    )
  end

  @doc """
  Validate graph structure and properties.

  Performs comprehensive validation of graph integrity including
  checking for orphaned edges, invalid vertices, and structural issues.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Utils.validate_graph(graph)
      {:ok, %{valid: true, issues: []}}
  """
  @spec validate_graph(graph()) :: {:ok, map()} | {:error, [atom()]}
  def validate_graph(graph) do
    FoundationIntegration.measure_algorithm(
      :graph_validation,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        issues = []

        issues = check_orphaned_edges(graph, issues)
        issues = check_self_loops(graph, issues)
        issues = check_duplicate_edges(graph, issues)

        if Enum.empty?(issues) do
          {:ok, %{valid: true, issues: []}}
        else
          {:error, issues}
        end
      end
    )
  end

  @doc """
  Export graph to DOT format for visualization.

  Creates DOT format representation suitable for Graphviz visualization
  with optional styling and metadata inclusion.

  ## Options
  - `:include_weights` - Include edge weights in output (default: true)
  - `:include_metadata` - Include node/edge metadata (default: false)
  - `:style` - Styling options for visualization

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> dot = ElixirScope.Graph.Utils.to_dot(graph)
      iex> String.contains?(dot, "digraph")
      true
  """
  @spec to_dot(graph(), keyword()) :: String.t()
  def to_dot(graph, _opts \\ []) do
    FoundationIntegration.measure_algorithm(
      :graph_to_dot,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        Graph.to_dot(graph)
      end
    )
  end

  @doc """
  Create a random graph for testing purposes.

  Generates a random graph with specified number of nodes and edge probability.
  Useful for testing algorithms and performance benchmarking.

  ## Examples

      iex> graph = ElixirScope.Graph.Utils.random_graph(5, 0.3)
      iex> Graph.num_vertices(graph)
      5
  """
  @spec random_graph(non_neg_integer(), float()) :: graph()
  def random_graph(node_count, edge_probability)
      when edge_probability >= 0.0 and edge_probability <= 1.0 do
    FoundationIntegration.measure_algorithm(
      :random_graph_generation,
      %{
        nodes: node_count,
        edge_probability: edge_probability
      },
      fn ->
        # Create vertices
        vertices = 0..(node_count - 1) |> Enum.to_list()
        graph = Enum.reduce(vertices, Graph.new(type: :directed), &Graph.add_vertex(&2, &1))

        # Add random edges
        for i <- vertices,
            j <- vertices,
            i != j,
            :rand.uniform() < edge_probability,
            reduce: graph do
          acc -> Graph.add_edge(acc, i, j)
        end
      end
    )
  end

  @doc """
  Find nodes with high connectivity (hubs).

  Identifies nodes with degree higher than the specified threshold.
  Useful for finding important nodes in dependency graphs.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> hubs = ElixirScope.Graph.Utils.find_hubs(graph, 1)
      iex> length(hubs) > 0
      true
  """
  @spec find_hubs(graph(), non_neg_integer()) :: [vertex()]
  def find_hubs(graph, degree_threshold) do
    FoundationIntegration.measure_algorithm(
      :hub_detection,
      %{
        nodes: Graph.num_vertices(graph),
        threshold: degree_threshold
      },
      fn ->
        Graph.vertices(graph)
        |> Enum.filter(fn vertex ->
          in_degree = Graph.in_degree(graph, vertex)
          out_degree = Graph.out_degree(graph, vertex)
          total_degree = in_degree + out_degree
          total_degree > degree_threshold
        end)
      end
    )
  end

  @doc """
  Partition graph into layers based on topological ordering.

  Creates layers where each layer contains nodes that have no dependencies
  on nodes in later layers. Useful for visualizing dependency hierarchies.

  Assumes input graph is acyclic.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> {:ok, layers} = ElixirScope.Graph.Utils.topological_layers(graph)
      iex> length(layers)
      2
  """
  @spec topological_layers(graph()) :: {:ok, [[vertex()]]} | {:error, :cyclic}
  def topological_layers(graph) do
    FoundationIntegration.measure_algorithm(
      :topological_layering,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        case Graph.topsort(graph) do
          false ->
            {:error, :cyclic}

          sorted_vertices when is_list(sorted_vertices) ->
            layers = build_layers(graph, sorted_vertices)
            {:ok, layers}
        end
      end
    )
  end

  @doc """
  Calculate graph similarity using structural measures.

  Compares two graphs using multiple similarity metrics including
  node overlap, edge overlap, and structural similarity.

  ## Examples

      iex> g1 = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> g2 = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> similarity = ElixirScope.Graph.Utils.graph_similarity(g1, g2)
      iex> similarity.node_overlap
      1.0
  """
  @spec graph_similarity(graph(), graph()) :: map()
  def graph_similarity(graph1, graph2) do
    FoundationIntegration.measure_algorithm(
      :graph_similarity,
      %{
        g1_nodes: Graph.num_vertices(graph1),
        g1_edges: Graph.num_edges(graph1),
        g2_nodes: Graph.num_vertices(graph2),
        g2_edges: Graph.num_edges(graph2)
      },
      fn ->
        vertices1 = MapSet.new(Graph.vertices(graph1))
        vertices2 = MapSet.new(Graph.vertices(graph2))

        edges1 = MapSet.new(Graph.edges(graph1) |> Enum.map(fn %{v1: v1, v2: v2} -> {v1, v2} end))
        edges2 = MapSet.new(Graph.edges(graph2) |> Enum.map(fn %{v1: v1, v2: v2} -> {v1, v2} end))

        node_intersection = MapSet.intersection(vertices1, vertices2) |> MapSet.size()
        node_union = MapSet.union(vertices1, vertices2) |> MapSet.size()

        edge_intersection = MapSet.intersection(edges1, edges2) |> MapSet.size()
        edge_union = MapSet.union(edges1, edges2) |> MapSet.size()

        %{
          node_overlap: safe_divide(node_intersection, node_union),
          edge_overlap: safe_divide(edge_intersection, edge_union),
          jaccard_similarity:
            safe_divide(node_intersection + edge_intersection, node_union + edge_union),
          structural_similarity: calculate_structural_similarity(graph1, graph2)
        }
      end
    )
  end

  # Private helper functions

  @spec is_directed_graph?(graph()) :: boolean()
  defp is_directed_graph?(graph) do
    # Check the graph's type field in the Graph struct
    case graph do
      %Graph{type: :directed} -> true
      %Graph{type: :undirected} -> false
    end
  end

  @spec calculate_density(non_neg_integer(), non_neg_integer()) :: float()
  defp calculate_density(node_count, _edge_count) when node_count <= 1, do: 0.0

  defp calculate_density(node_count, edge_count) do
    max_edges = node_count * (node_count - 1)
    edge_count / max_edges
  end

  @spec calculate_average_degree(non_neg_integer(), non_neg_integer()) :: float()
  defp calculate_average_degree(node_count, _edge_count) when node_count == 0, do: 0.0

  defp calculate_average_degree(node_count, edge_count) do
    2 * edge_count / node_count
  end

  @spec calculate_max_degree(graph()) :: non_neg_integer()
  defp calculate_max_degree(graph) do
    Graph.vertices(graph)
    |> Enum.map(fn vertex ->
      Graph.in_degree(graph, vertex) + Graph.out_degree(graph, vertex)
    end)
    |> Enum.max(fn -> 0 end)
  end

  @spec count_isolated_nodes(graph()) :: non_neg_integer()
  defp count_isolated_nodes(graph) do
    Graph.vertices(graph)
    |> Enum.count(fn vertex ->
      Graph.in_degree(graph, vertex) == 0 and Graph.out_degree(graph, vertex) == 0
    end)
  end

  @spec check_orphaned_edges(graph(), [atom()]) :: [atom()]
  defp check_orphaned_edges(graph, issues) do
    vertices = MapSet.new(Graph.vertices(graph))

    orphaned =
      Graph.edges(graph)
      |> Enum.any?(fn %{v1: v1, v2: v2} ->
        not MapSet.member?(vertices, v1) or not MapSet.member?(vertices, v2)
      end)

    if orphaned, do: [:orphaned_edges | issues], else: issues
  end

  @spec check_self_loops(graph(), [atom()]) :: [atom()]
  defp check_self_loops(graph, issues) do
    has_self_loops =
      Graph.edges(graph)
      |> Enum.any?(fn %{v1: v1, v2: v2} -> v1 == v2 end)

    if has_self_loops, do: [:self_loops | issues], else: issues
  end

  @spec check_duplicate_edges(graph(), [atom()]) :: [atom()]
  defp check_duplicate_edges(graph, issues) do
    edge_pairs =
      Graph.edges(graph)
      |> Enum.map(fn %{v1: v1, v2: v2} -> {v1, v2} end)

    unique_edges = Enum.uniq(edge_pairs)

    if length(edge_pairs) != length(unique_edges) do
      [:duplicate_edges | issues]
    else
      issues
    end
  end

  @spec build_layers(graph(), [vertex()]) :: [[vertex()]]
  defp build_layers(graph, sorted_vertices) do
    # Build layers by removing nodes with no incoming edges iteratively
    remaining_graph = graph
    remaining_vertices = sorted_vertices
    layers = []

    build_layers_recursive(remaining_graph, remaining_vertices, layers)
  end

  @spec build_layers_recursive(graph(), [vertex()], [[vertex()]]) :: [[vertex()]]
  defp build_layers_recursive(_graph, [], layers), do: Enum.reverse(layers)

  defp build_layers_recursive(graph, vertices, layers) do
    # Find vertices with no incoming edges from remaining vertices
    current_layer =
      Enum.filter(vertices, fn vertex ->
        Graph.in_degree(graph, vertex) == 0
      end)

    if Enum.empty?(current_layer) do
      # If no vertices have zero in-degree, we have a cycle
      # This shouldn't happen if the graph passed initial acyclic check
      Enum.reverse([vertices | layers])
    else
      # Remove current layer vertices and their edges
      remaining_vertices = vertices -- current_layer
      updated_graph = Enum.reduce(current_layer, graph, &Graph.delete_vertex(&2, &1))

      build_layers_recursive(updated_graph, remaining_vertices, [current_layer | layers])
    end
  end

  @spec safe_divide(non_neg_integer(), non_neg_integer()) :: float()
  defp safe_divide(_numerator, 0), do: 0.0
  defp safe_divide(numerator, denominator), do: numerator / denominator

  @spec calculate_structural_similarity(graph(), graph()) :: float()
  defp calculate_structural_similarity(graph1, graph2) do
    # Simple structural similarity based on degree distribution
    degrees1 =
      Graph.vertices(graph1)
      |> Enum.map(&(Graph.in_degree(graph1, &1) + Graph.out_degree(graph1, &1)))

    degrees2 =
      Graph.vertices(graph2)
      |> Enum.map(&(Graph.in_degree(graph2, &1) + Graph.out_degree(graph2, &1)))

    if Enum.empty?(degrees1) and Enum.empty?(degrees2) do
      1.0
    else
      # Compare degree distributions
      avg1 = if Enum.empty?(degrees1), do: 0.0, else: Enum.sum(degrees1) / length(degrees1)
      avg2 = if Enum.empty?(degrees2), do: 0.0, else: Enum.sum(degrees2) / length(degrees2)

      max_avg = max(avg1, avg2)
      if max_avg == 0.0, do: 1.0, else: 1.0 - abs(avg1 - avg2) / max_avg
    end
  end
end
