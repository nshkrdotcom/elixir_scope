defmodule ElixirScope.Graph.Algorithms.ModuleClustering do
  @moduledoc """
  Module clustering algorithms for identifying cohesive groups in code.

  This module provides algorithms to detect communities and clusters within
  software dependency graphs, helping identify modules that belong together
  and potential architectural boundaries.
  """

  alias ElixirScope.Graph.FoundationIntegration

  @type graph :: Graph.t()
  @type vertex :: term()
  @type cluster :: [vertex()]
  @type modularity :: float()

  @doc """
  Detect cohesive module clusters using community detection.

  Identifies groups of modules that are more densely connected to each other
  than to modules outside the group. Uses a modularity-based approach.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> clusters = ElixirScope.Graph.Algorithms.ModuleClustering.cohesive_modules(graph)
      iex> is_list(clusters)
      true
  """
  @spec cohesive_modules(graph(), keyword()) :: [cluster()]
  def cohesive_modules(dependency_graph, opts \\ []) do
    FoundationIntegration.measure_algorithm(
      :cohesive_modules,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        config = FoundationIntegration.get_config(:graph_algorithms)
        clustering_config = Map.get(config, :community_detection, %{})

        resolution = Keyword.get(opts, :resolution, Map.get(clustering_config, :resolution, 1.0))

        max_iterations =
          Keyword.get(opts, :max_iterations, Map.get(clustering_config, :max_iterations, 100))

        louvain_clustering(dependency_graph, resolution, max_iterations)
      end
    )
  end

  @doc """
  Calculate modularity score for a given clustering.

  Measures how good a particular clustering is by comparing the number of edges
  within clusters to what would be expected in a random graph.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> clusters = [[:a], [:b]]
      iex> modularity = ElixirScope.Graph.Algorithms.ModuleClustering.calculate_modularity(graph, clusters)
      iex> is_float(modularity)
      true
  """
  @spec calculate_modularity(graph(), [cluster()]) :: modularity()
  def calculate_modularity(graph, clusters) do
    FoundationIntegration.measure_algorithm(
      :modularity_calculation,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph),
        clusters: length(clusters)
      },
      fn ->
        # Create cluster membership map
        cluster_membership = create_cluster_membership_map(clusters)

        # Calculate modularity using Newman's formula
        total_edges = Graph.num_edges(graph)

        if total_edges == 0 do
          0.0
        else
          vertices = Graph.vertices(graph)

          modularity_sum =
            Enum.reduce(vertices, 0.0, fn v1, acc1 ->
              Enum.reduce(vertices, acc1, fn v2, acc2 ->
                # Check if vertices are in the same cluster
                same_cluster = Map.get(cluster_membership, v1) == Map.get(cluster_membership, v2)

                if same_cluster do
                  # A_ij - (k_i * k_j) / (2m)
                  a_ij = if Graph.edge(graph, v1, v2), do: 1, else: 0
                  k_i = Graph.out_degree(graph, v1) + Graph.in_degree(graph, v1)
                  k_j = Graph.out_degree(graph, v2) + Graph.in_degree(graph, v2)

                  expected = k_i * k_j / (2 * total_edges)
                  acc2 + (a_ij - expected)
                else
                  acc2
                end
              end)
            end)

          modularity_sum / (2 * total_edges)
        end
      end
    )
  end

  @doc """
  Identify modules that bridge different clusters.

  Finds modules that have connections to multiple clusters and could
  serve as integration points or architectural bridges.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> clusters = [[:a], [:b]]
      iex> bridges = ElixirScope.Graph.Algorithms.ModuleClustering.find_bridge_modules(graph, clusters)
      iex> is_list(bridges)
      true
  """
  @spec find_bridge_modules(graph(), [cluster()]) :: [vertex()]
  def find_bridge_modules(graph, clusters) do
    FoundationIntegration.measure_algorithm(
      :bridge_module_detection,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph),
        clusters: length(clusters)
      },
      fn ->
        cluster_membership = create_cluster_membership_map(clusters)

        Graph.vertices(graph)
        |> Enum.filter(fn vertex ->
          # Get all neighbors
          neighbors = Graph.out_neighbors(graph, vertex) ++ Graph.in_neighbors(graph, vertex)

          neighbor_clusters =
            neighbors
            |> Enum.map(fn neighbor -> Map.get(cluster_membership, neighbor) end)
            |> Enum.uniq()
            |> Enum.reject(&is_nil/1)

          # Vertex is a bridge if it connects to multiple clusters
          length(neighbor_clusters) > 1
        end)
      end
    )
  end

  @doc """
  Analyze cluster cohesion and coupling metrics.

  Calculates detailed metrics about each cluster including internal cohesion,
  external coupling, and stability measures.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> clusters = [[:a, :b]]
      iex> metrics = ElixirScope.Graph.Algorithms.ModuleClustering.cluster_metrics(graph, clusters)
      iex> is_map(metrics)
      true
  """
  @spec cluster_metrics(graph(), [cluster()]) :: map()
  def cluster_metrics(graph, clusters) do
    FoundationIntegration.measure_algorithm(
      :cluster_metrics,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph),
        clusters: length(clusters)
      },
      fn ->
        cluster_membership = create_cluster_membership_map(clusters)

        cluster_stats =
          Enum.with_index(clusters)
          |> Enum.map(fn {cluster, index} ->
            {index, analyze_single_cluster(graph, cluster, cluster_membership)}
          end)
          |> Map.new()

        %{
          cluster_count: length(clusters),
          cluster_stats: cluster_stats,
          overall_modularity: calculate_modularity(graph, clusters),
          bridge_modules: find_bridge_modules(graph, clusters)
        }
      end
    )
  end

  @doc """
  Detect hierarchical clustering using recursive community detection.

  Creates a hierarchy of clusters by recursively applying community detection
  to sub-clusters, revealing multi-level architectural structure.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> hierarchy = ElixirScope.Graph.Algorithms.ModuleClustering.hierarchical_clustering(graph)
      iex> is_map(hierarchy)
      true
  """
  @spec hierarchical_clustering(graph(), keyword()) :: map()
  def hierarchical_clustering(graph, opts \\ []) do
    FoundationIntegration.measure_algorithm(
      :hierarchical_clustering,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        max_depth = Keyword.get(opts, :max_depth, 3)
        min_cluster_size = Keyword.get(opts, :min_cluster_size, 2)

        build_hierarchy(graph, max_depth, min_cluster_size, 0)
      end
    )
  end

  @doc """
  Suggest optimal cluster boundaries based on multiple criteria.

  Analyzes the graph to suggest where cluster boundaries should be placed
  based on dependency patterns, modularity, and architectural principles.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> suggestions = ElixirScope.Graph.Algorithms.ModuleClustering.suggest_cluster_boundaries(graph)
      iex> Map.has_key?(suggestions, :recommended_clusters)
      true
  """
  @spec suggest_cluster_boundaries(graph()) :: map()
  def suggest_cluster_boundaries(graph) do
    FoundationIntegration.measure_algorithm(
      :cluster_boundary_suggestion,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        # Try different clustering approaches
        base_clusters = cohesive_modules(graph)

        # Calculate multiple quality metrics
        modularity_score = calculate_modularity(graph, base_clusters)
        bridge_modules = find_bridge_modules(graph, base_clusters)

        # Analyze cluster sizes and balance
        cluster_sizes = Enum.map(base_clusters, &length/1)
        size_variance = calculate_variance(cluster_sizes)

        # Suggest improvements
        improvements = suggest_improvements(graph, base_clusters, modularity_score)

        %{
          recommended_clusters: base_clusters,
          modularity_score: modularity_score,
          cluster_count: length(base_clusters),
          cluster_sizes: cluster_sizes,
          size_variance: size_variance,
          bridge_modules: bridge_modules,
          improvement_suggestions: improvements
        }
      end
    )
  end

  # Private helper functions

  @spec louvain_clustering(graph(), float(), integer()) :: [cluster()]
  defp louvain_clustering(graph, resolution, max_iterations) do
    # Initialize each vertex in its own cluster
    vertices = Graph.vertices(graph)
    initial_clusters = Enum.map(vertices, fn v -> [v] end)

    # Iteratively improve clustering
    iterate_louvain(graph, initial_clusters, resolution, max_iterations, 0)
  end

  @spec iterate_louvain(graph(), [cluster()], float(), integer(), integer()) :: [cluster()]
  defp iterate_louvain(_graph, clusters, _resolution, max_iterations, iteration)
       when iteration >= max_iterations,
       do: clusters

  defp iterate_louvain(graph, clusters, resolution, max_iterations, iteration) do
    # Try to improve clustering by moving vertices between clusters
    improved_clusters = improve_clustering_pass(graph, clusters, resolution)

    # Check if improvement was made
    if clusters == improved_clusters do
      # No improvement, stop
      clusters
    else
      iterate_louvain(graph, improved_clusters, resolution, max_iterations, iteration + 1)
    end
  end

  @spec improve_clustering_pass(graph(), [cluster()], float()) :: [cluster()]
  defp improve_clustering_pass(graph, clusters, resolution) do
    _cluster_membership = create_cluster_membership_map(clusters)

    # For each vertex, try moving it to neighboring clusters
    Graph.vertices(graph)
    |> Enum.reduce(clusters, fn vertex, current_clusters ->
      try_vertex_moves(graph, vertex, current_clusters, resolution)
    end)
  end

  @spec try_vertex_moves(graph(), vertex(), [cluster()], float()) :: [cluster()]
  defp try_vertex_moves(graph, vertex, clusters, _resolution) do
    # Simple heuristic: move vertex to the cluster with most connections
    neighbors = Graph.out_neighbors(graph, vertex) ++ Graph.in_neighbors(graph, vertex)
    cluster_membership = create_cluster_membership_map(clusters)

    # Count connections to each cluster
    cluster_connections =
      Enum.reduce(neighbors, %{}, fn neighbor, acc ->
        cluster_id = Map.get(cluster_membership, neighbor)

        if cluster_id do
          Map.update(acc, cluster_id, 1, &(&1 + 1))
        else
          acc
        end
      end)

    if Enum.empty?(cluster_connections) do
      clusters
    else
      # Find cluster with most connections
      {best_cluster_id, _count} = Enum.max_by(cluster_connections, fn {_id, count} -> count end)

      # Move vertex to best cluster
      move_vertex_to_cluster(vertex, best_cluster_id, clusters)
    end
  end

  @spec move_vertex_to_cluster(vertex(), integer(), [cluster()]) :: [cluster()]
  defp move_vertex_to_cluster(vertex, target_cluster_id, clusters) do
    # Remove vertex from current cluster
    clusters_without_vertex =
      Enum.map(clusters, fn cluster ->
        Enum.reject(cluster, fn v -> v == vertex end)
      end)
      # Remove empty clusters
      |> Enum.reject(&Enum.empty?/1)

    # Add vertex to target cluster
    Enum.with_index(clusters_without_vertex)
    |> Enum.map(fn {cluster, index} ->
      if index == target_cluster_id do
        [vertex | cluster]
      else
        cluster
      end
    end)
  end

  @spec create_cluster_membership_map([cluster()]) :: %{vertex() => integer()}
  defp create_cluster_membership_map(clusters) do
    clusters
    |> Enum.with_index()
    |> Enum.flat_map(fn {cluster, index} ->
      Enum.map(cluster, fn vertex -> {vertex, index} end)
    end)
    |> Map.new()
  end

  @spec analyze_single_cluster(graph(), cluster(), %{vertex() => integer()}) :: map()
  defp analyze_single_cluster(graph, cluster, _cluster_membership) do
    cluster_set = MapSet.new(cluster)

    # Count internal and external edges
    {internal_edges, external_edges} =
      Enum.reduce(cluster, {0, 0}, fn vertex, {internal, external} ->
        neighbors = Graph.out_neighbors(graph, vertex) ++ Graph.in_neighbors(graph, vertex)

        Enum.reduce(neighbors, {internal, external}, fn neighbor, {int_acc, ext_acc} ->
          if MapSet.member?(cluster_set, neighbor) do
            {int_acc + 1, ext_acc}
          else
            {int_acc, ext_acc + 1}
          end
        end)
      end)

    total_edges = internal_edges + external_edges

    %{
      size: length(cluster),
      internal_edges: internal_edges,
      external_edges: external_edges,
      cohesion: if(total_edges > 0, do: internal_edges / total_edges, else: 0.0),
      coupling: external_edges,
      density: calculate_cluster_density(cluster, internal_edges)
    }
  end

  @spec calculate_cluster_density(cluster(), integer()) :: float()
  defp calculate_cluster_density(cluster, _internal_edges) when length(cluster) <= 1, do: 0.0

  defp calculate_cluster_density(cluster, internal_edges) do
    n = length(cluster)
    # Maximum possible edges in directed graph
    max_edges = n * (n - 1)
    internal_edges / max_edges
  end

  @spec build_hierarchy(graph(), integer(), integer(), integer()) :: map()
  defp build_hierarchy(graph, max_depth, _min_cluster_size, current_depth)
       when current_depth >= max_depth do
    %{
      level: current_depth,
      clusters: [Graph.vertices(graph)],
      children: []
    }
  end

  defp build_hierarchy(graph, max_depth, min_cluster_size, current_depth) do
    clusters = cohesive_modules(graph)

    # Only recurse on clusters larger than minimum size
    large_clusters = Enum.filter(clusters, fn cluster -> length(cluster) >= min_cluster_size end)

    children =
      Enum.map(large_clusters, fn cluster ->
        if length(cluster) > min_cluster_size do
          subgraph = Graph.subgraph(graph, cluster)
          build_hierarchy(subgraph, max_depth, min_cluster_size, current_depth + 1)
        else
          %{level: current_depth + 1, clusters: [cluster], children: []}
        end
      end)

    %{
      level: current_depth,
      clusters: clusters,
      children: children
    }
  end

  @spec calculate_variance([number()]) :: float()
  defp calculate_variance([]), do: 0.0

  defp calculate_variance(values) do
    n = length(values)
    mean = Enum.sum(values) / n

    sum_of_squares =
      Enum.reduce(values, 0, fn value, acc ->
        diff = value - mean
        acc + diff * diff
      end)

    sum_of_squares / n
  end

  @spec suggest_improvements(graph(), [cluster()], float()) :: [String.t()]
  defp suggest_improvements(graph, clusters, modularity_score) do
    suggestions = []

    # Low modularity suggestion
    suggestions =
      if modularity_score < 0.3 do
        [
          "Consider restructuring: Low modularity score (#{Float.round(modularity_score, 3)}) indicates weak clustering"
          | suggestions
        ]
      else
        suggestions
      end

    # Large cluster suggestion
    large_clusters = Enum.filter(clusters, fn cluster -> length(cluster) > 10 end)

    suggestions =
      if length(large_clusters) > 0 do
        [
          "Consider splitting large clusters (#{length(large_clusters)} clusters with >10 modules)"
          | suggestions
        ]
      else
        suggestions
      end

    # Small cluster suggestion
    small_clusters = Enum.filter(clusters, fn cluster -> length(cluster) == 1 end)

    suggestions =
      if length(small_clusters) > length(clusters) / 3 do
        [
          "Consider merging small clusters (#{length(small_clusters)} singleton clusters)"
          | suggestions
        ]
      else
        suggestions
      end

    # High coupling suggestion
    bridge_modules = find_bridge_modules(graph, clusters)

    suggestions =
      if length(bridge_modules) > length(Graph.vertices(graph)) / 4 do
        [
          "High coupling detected: #{length(bridge_modules)} bridge modules suggest need for better separation"
          | suggestions
        ]
      else
        suggestions
      end

    if Enum.empty?(suggestions) do
      ["Clustering appears well-structured with good modularity and balance"]
    else
      suggestions
    end
  end
end
