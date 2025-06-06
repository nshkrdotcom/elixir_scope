defmodule ElixirScope.Graph.Algorithms.CodeCentrality do
  @moduledoc """
  Code-specific centrality algorithms for analyzing software dependencies.

  This module provides centrality measures tailored for code analysis,
  combining traditional graph centrality with software engineering metrics
  like dependency fan-out, complexity, and usage patterns.
  """

  alias ElixirScope.Graph.FoundationIntegration

  @type graph :: Graph.t()
  @type vertex :: term()
  @type centrality_scores :: %{vertex() => float()}

  @doc """
  Calculate dependency importance using a weighted combination of centrality measures.

  Combines betweenness centrality with dependency fan-out to identify critical
  components in the dependency graph. Higher scores indicate more important modules.

  ## Algorithm
  1. Calculate betweenness centrality (how often a node is on shortest paths)
  2. Calculate dependency fan-out (how many other modules depend on this one)
  3. Combine with weights: importance = 0.7 * betweenness + 0.3 * fan_out

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> importance = ElixirScope.Graph.Algorithms.CodeCentrality.dependency_importance(graph)
      iex> is_map(importance)
      true
  """
  @spec dependency_importance(graph()) :: centrality_scores()
  def dependency_importance(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :dependency_importance,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        # Calculate betweenness centrality using custom implementation
        betweenness = calculate_simple_betweenness(dependency_graph)

        # Calculate dependency fan-out (custom metric)
        fan_out = calculate_dependency_fan_out(dependency_graph)

        # Combine metrics with weights optimized for code analysis
        combine_centrality_measures(betweenness, fan_out, 0.7, 0.3)
      end
    )
  end

  @doc """
  Calculate module influence using PageRank-style algorithm.

  Adapts PageRank for dependency graphs where influence flows from dependencies
  to dependents. Modules that are depended upon by many other influential modules
  get higher scores.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> influence = ElixirScope.Graph.Algorithms.CodeCentrality.module_influence(graph)
      iex> is_map(influence)
      true
  """
  @spec module_influence(graph()) :: centrality_scores()
  def module_influence(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :module_influence,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        config = FoundationIntegration.get_config(:graph_algorithms)
        pagerank_config = Map.get(config, :pagerank, %{})

        max_iterations = Map.get(pagerank_config, :max_iterations, 100)
        damping_factor = Map.get(pagerank_config, :damping_factor, 0.85)
        tolerance = Map.get(pagerank_config, :tolerance, 1.0e-6)

        pagerank_algorithm(dependency_graph, damping_factor, max_iterations, tolerance)
      end
    )
  end

  @doc """
  Calculate critical path centrality for identifying bottlenecks.

  Identifies nodes that appear frequently on critical paths (longest paths)
  through the dependency graph. High scores indicate potential bottlenecks.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> critical = ElixirScope.Graph.Algorithms.CodeCentrality.critical_path_centrality(graph)
      iex> is_map(critical)
      true
  """
  @spec critical_path_centrality(graph()) :: centrality_scores()
  def critical_path_centrality(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :critical_path_centrality,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        # Find longest paths from each source node
        source_nodes = find_source_nodes(dependency_graph)

        # Calculate how often each node appears on critical paths
        critical_path_frequencies =
          Enum.reduce(source_nodes, %{}, fn source, acc ->
            case find_longest_paths_from_source(dependency_graph, source) do
              [] ->
                acc

              paths ->
                Enum.reduce(paths, acc, fn path, inner_acc ->
                  Enum.reduce(path, inner_acc, fn node, node_acc ->
                    Map.update(node_acc, node, 1, &(&1 + 1))
                  end)
                end)
            end
          end)

        # Normalize by total number of paths
        total_paths = Enum.sum(Map.values(critical_path_frequencies))
        normalize_scores(critical_path_frequencies, total_paths)
      end
    )
  end

  @doc """
  Calculate change impact centrality for predicting ripple effects.

  Estimates how many other modules would be affected if a module changes.
  Combines forward and backward dependency analysis.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> impact = ElixirScope.Graph.Algorithms.CodeCentrality.change_impact_centrality(graph)
      iex> is_map(impact)
      true
  """
  @spec change_impact_centrality(graph()) :: centrality_scores()
  def change_impact_centrality(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :change_impact_centrality,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        vertices = Graph.vertices(dependency_graph)

        Enum.reduce(vertices, %{}, fn vertex, acc ->
          # Forward impact: modules that depend on this one (directly or indirectly)
          forward_impact = Graph.reachable(dependency_graph, [vertex]) |> length()

          # Backward impact: modules this one depends on (reverse graph)
          reverse_graph = Graph.transpose(dependency_graph)
          backward_impact = Graph.reachable(reverse_graph, [vertex]) |> length()

          # Combined impact score
          total_impact = forward_impact + backward_impact
          normalized_impact = total_impact / length(vertices)

          Map.put(acc, vertex, normalized_impact)
        end)
      end
    )
  end

  @doc """
  Calculate composite centrality score using multiple measures.

  Combines multiple centrality measures with configurable weights to provide
  a comprehensive importance score for each module.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> composite = ElixirScope.Graph.Algorithms.CodeCentrality.composite_centrality(graph)
      iex> is_map(composite)
      true
  """
  @spec composite_centrality(graph()) :: centrality_scores()
  def composite_centrality(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :composite_centrality,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        # Calculate individual centrality measures
        betweenness = calculate_simple_betweenness(dependency_graph)
        closeness = calculate_simple_closeness(dependency_graph)
        dependency_importance = dependency_importance(dependency_graph)
        change_impact = change_impact_centrality(dependency_graph)

        # Get weights from configuration
        config = FoundationIntegration.get_config(:graph_algorithms)
        centrality_config = Map.get(config, :centrality, %{})

        weights = %{
          betweenness: Map.get(centrality_config, :betweenness_weight, 0.3),
          closeness: Map.get(centrality_config, :closeness_weight, 0.2),
          dependency: Map.get(centrality_config, :dependency_weight, 0.3),
          change_impact: Map.get(centrality_config, :change_impact_weight, 0.2)
        }

        # Combine all measures
        vertices = Graph.vertices(dependency_graph)

        Enum.reduce(vertices, %{}, fn vertex, acc ->
          composite_score =
            Map.get(betweenness, vertex, 0.0) * weights.betweenness +
              Map.get(closeness, vertex, 0.0) * weights.closeness +
              Map.get(dependency_importance, vertex, 0.0) * weights.dependency +
              Map.get(change_impact, vertex, 0.0) * weights.change_impact

          Map.put(acc, vertex, composite_score)
        end)
      end
    )
  end

  # Private helper functions

  # Wrapper to handle libgraph version differences
  @spec safe_dijkstra(graph(), vertex(), vertex()) :: [vertex()]
  defp safe_dijkstra(graph, source, target) do
    result = Graph.dijkstra(graph, source, target)
    if is_list(result), do: result, else: []
  end

  @spec calculate_simple_betweenness(graph()) :: centrality_scores()
  defp calculate_simple_betweenness(graph) do
    vertices = Graph.vertices(graph)

    # For small graphs, use simple algorithm
    if length(vertices) <= 100 do
      # Initialize centrality scores
      centrality = Map.new(vertices, fn v -> {v, 0.0} end)

      # For each pair of vertices, find paths and count how often each vertex is in between
      Enum.reduce(vertices, centrality, fn source, acc ->
        Enum.reduce(vertices, acc, fn target, inner_acc ->
          if source != target do
            paths = Graph.get_paths(graph, source, target)

            if length(paths) > 0 do
              # Get shortest paths only
              min_length = paths |> Enum.map(&length/1) |> Enum.min()
              shortest_paths = Enum.filter(paths, fn path -> length(path) == min_length end)
              shortest_count = length(shortest_paths)

              if shortest_count > 0 do
                # For each shortest path, increment centrality of intermediate vertices
                Enum.reduce(shortest_paths, inner_acc, fn path, path_acc ->
                  intermediate_vertices = Enum.slice(path, 1..-2//1)

                  Enum.reduce(intermediate_vertices, path_acc, fn vertex, vertex_acc ->
                    Map.update(
                      vertex_acc,
                      vertex,
                      1.0 / shortest_count,
                      &(&1 + 1.0 / shortest_count)
                    )
                  end)
                end)
              else
                inner_acc
              end
            else
              inner_acc
            end
          else
            inner_acc
          end
        end)
      end)
    else
      # For larger graphs, use degree centrality as approximation
      Map.new(vertices, fn vertex ->
        degree = Graph.degree(graph, vertex)
        {vertex, degree / length(vertices)}
      end)
    end
  end

  @spec calculate_simple_closeness(graph()) :: centrality_scores()
  defp calculate_simple_closeness(graph) do
    vertices = Graph.vertices(graph)

    Map.new(vertices, fn vertex ->
      # Calculate sum of shortest path distances from this vertex to all others
      total_distance =
        Enum.reduce(vertices, 0, fn target, acc ->
          if vertex != target do
            case safe_dijkstra(graph, vertex, target) do
              # Empty path means unreachable
              [] -> acc + 1000
              # Path length minus 1 for distance
              path -> acc + (length(path) - 1)
            end
          else
            acc
          end
        end)

      # Closeness is reciprocal of total distance
      closeness = if total_distance > 0, do: 1.0 / total_distance, else: 0.0
      {vertex, closeness}
    end)
  end

  @spec calculate_dependency_fan_out(graph()) :: centrality_scores()
  defp calculate_dependency_fan_out(dependency_graph) do
    vertices = Graph.vertices(dependency_graph)
    total_vertices = length(vertices)

    Enum.reduce(vertices, %{}, fn vertex, acc ->
      # Count how many modules depend on this vertex
      dependents = Graph.in_neighbors(dependency_graph, vertex)

      fan_out_score =
        if total_vertices > 1, do: length(dependents) / (total_vertices - 1), else: 0.0

      Map.put(acc, vertex, fan_out_score)
    end)
  end

  @spec combine_centrality_measures(centrality_scores(), centrality_scores(), float(), float()) ::
          centrality_scores()
  defp combine_centrality_measures(measure1, measure2, weight1, weight2) do
    all_vertices = MapSet.union(MapSet.new(Map.keys(measure1)), MapSet.new(Map.keys(measure2)))

    Enum.reduce(all_vertices, %{}, fn vertex, acc ->
      score1 = Map.get(measure1, vertex, 0.0)
      score2 = Map.get(measure2, vertex, 0.0)
      combined_score = score1 * weight1 + score2 * weight2
      Map.put(acc, vertex, combined_score)
    end)
  end

  @spec pagerank_algorithm(graph(), float(), integer(), float()) :: centrality_scores()
  defp pagerank_algorithm(graph, damping_factor, max_iterations, tolerance) do
    vertices = Graph.vertices(graph)
    n = length(vertices)

    # Initial scores: 1/n for each vertex
    initial_score = 1.0 / n
    scores = Enum.reduce(vertices, %{}, fn vertex, acc -> Map.put(acc, vertex, initial_score) end)

    # Iterative PageRank calculation
    iterate_pagerank(graph, scores, damping_factor, max_iterations, tolerance, 0)
  end

  @spec iterate_pagerank(graph(), centrality_scores(), float(), integer(), float(), integer()) ::
          centrality_scores()
  defp iterate_pagerank(_graph, scores, _damping_factor, max_iterations, _tolerance, iteration)
       when iteration >= max_iterations,
       do: scores

  defp iterate_pagerank(graph, scores, damping_factor, max_iterations, tolerance, iteration) do
    vertices = Graph.vertices(graph)
    n = length(vertices)

    new_scores =
      Enum.reduce(vertices, %{}, fn vertex, acc ->
        # Base score (random surfer)
        base_score = (1.0 - damping_factor) / n

        # Contribution from incoming edges
        incoming_contribution =
          Graph.in_neighbors(graph, vertex)
          |> Enum.reduce(0.0, fn neighbor, sum ->
            neighbor_score = Map.get(scores, neighbor, 0.0)
            neighbor_out_degree = Graph.out_degree(graph, neighbor)

            contribution =
              if neighbor_out_degree > 0, do: neighbor_score / neighbor_out_degree, else: 0.0

            sum + contribution
          end)

        new_score = base_score + damping_factor * incoming_contribution
        Map.put(acc, vertex, new_score)
      end)

    # Check for convergence
    max_change =
      vertices
      |> Enum.map(fn vertex ->
        abs(Map.get(new_scores, vertex, 0.0) - Map.get(scores, vertex, 0.0))
      end)
      |> Enum.max(fn -> 0.0 end)

    if max_change < tolerance do
      new_scores
    else
      iterate_pagerank(
        graph,
        new_scores,
        damping_factor,
        max_iterations,
        tolerance,
        iteration + 1
      )
    end
  end

  @spec find_source_nodes(graph()) :: [vertex()]
  defp find_source_nodes(graph) do
    Graph.vertices(graph)
    |> Enum.filter(fn vertex -> Graph.in_degree(graph, vertex) == 0 end)
  end

  @spec find_longest_paths_from_source(graph(), vertex()) :: [[vertex()]]
  defp find_longest_paths_from_source(graph, source) do
    # Use topological sort to find longest paths
    case Graph.topsort(graph) do
      # Graph has cycles
      false ->
        []

      sorted_vertices when is_list(sorted_vertices) ->
        # Find all paths from source using DFS with memoization
        find_longest_paths_dfs(graph, source, sorted_vertices)
    end
  end

  @spec find_longest_paths_dfs(graph(), vertex(), [vertex()]) :: [[vertex()]]
  defp find_longest_paths_dfs(graph, source, _sorted_vertices) do
    # Find all reachable vertices from source
    reachable_vertices = Graph.reachable(graph, [source])

    # Find all paths from source to reachable vertices
    all_paths =
      Enum.flat_map(reachable_vertices, fn target ->
        if target != source do
          Graph.get_paths(graph, source, target)
        else
          []
        end
      end)

    if Enum.empty?(all_paths) do
      [[source]]
    else
      max_length = all_paths |> Enum.map(&length/1) |> Enum.max()
      Enum.filter(all_paths, fn path -> length(path) == max_length end)
    end
  end

  @spec normalize_scores(map(), number()) :: centrality_scores()
  defp normalize_scores(scores, total) when total == 0, do: scores

  defp normalize_scores(scores, total) do
    Map.new(scores, fn {vertex, score} -> {vertex, score / total} end)
  end
end
