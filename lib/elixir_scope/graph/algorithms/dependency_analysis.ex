defmodule ElixirScope.Graph.Algorithms.DependencyAnalysis do
  @moduledoc """
  Specialized algorithms for analyzing code dependency structures.

  This module provides algorithms specifically designed for understanding
  and analyzing dependency relationships in software systems, including
  circular dependency detection, dependency chains, and architectural insights.
  """

  alias ElixirScope.Graph.FoundationIntegration

  @type graph :: Graph.t()
  @type vertex :: term()
  @type dependency_chain :: [vertex()]
  @type cycle :: [vertex()]

  @doc """
  Detect circular dependencies in the dependency graph.

  Identifies all strongly connected components with more than one node,
  which represent circular dependencies that may cause compilation or
  runtime issues.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b) |> Graph.add_edge(:b, :a)
      iex> cycles = ElixirScope.Graph.Algorithms.DependencyAnalysis.circular_dependencies(graph)
      iex> length(cycles) > 0
      true
  """
  @spec circular_dependencies(graph()) :: [cycle()]
  def circular_dependencies(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :circular_dependency_detection,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        # Find strongly connected components
        components = Graph.components(dependency_graph)

        # Filter out single-node components (not circular)
        circular_components =
          Enum.filter(components, fn component ->
            length(component) > 1 or has_self_loop?(dependency_graph, component)
          end)

        # Analyze each circular component for dependency information
        Enum.map(circular_components, fn component ->
          analyze_circular_component(dependency_graph, component)
        end)
      end
    )
  end

  @doc """
  Find the longest dependency chains in the system.

  Identifies the longest paths through the dependency graph, which can
  indicate potential compilation bottlenecks or architectural issues.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> chains = ElixirScope.Graph.Algorithms.DependencyAnalysis.longest_dependency_chains(graph)
      iex> is_list(chains)
      true
  """
  @spec longest_dependency_chains(graph()) :: [dependency_chain()]
  def longest_dependency_chains(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :longest_dependency_chains,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        case Graph.is_acyclic?(dependency_graph) do
          false ->
            # Graph has cycles, can't compute longest paths reliably
            []

          true ->
            # Find longest paths using topological sort
            find_longest_paths_in_dag(dependency_graph)
        end
      end
    )
  end

  @doc """
  Analyze dependency fan-out and fan-in patterns.

  Calculates fan-out (how many modules this one depends on) and
  fan-in (how many modules depend on this one) for each module.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> patterns = ElixirScope.Graph.Algorithms.DependencyAnalysis.dependency_patterns(graph)
      iex> Map.has_key?(patterns, :fan_out)
      true
  """
  @spec dependency_patterns(graph()) :: %{fan_out: map(), fan_in: map(), ratios: map()}
  def dependency_patterns(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :dependency_patterns,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        vertices = Graph.vertices(dependency_graph)

        {fan_out, fan_in} =
          Enum.reduce(vertices, {%{}, %{}}, fn vertex, {fo_acc, fi_acc} ->
            out_degree = Graph.out_degree(dependency_graph, vertex)
            in_degree = Graph.in_degree(dependency_graph, vertex)

            {
              Map.put(fo_acc, vertex, out_degree),
              Map.put(fi_acc, vertex, in_degree)
            }
          end)

        # Calculate fan-out/fan-in ratios
        ratios =
          Enum.reduce(vertices, %{}, fn vertex, acc ->
            out = Map.get(fan_out, vertex, 0)
            in_val = Map.get(fan_in, vertex, 0)
            ratio = if in_val > 0, do: out / in_val, else: :infinity
            Map.put(acc, vertex, ratio)
          end)

        %{
          fan_out: fan_out,
          fan_in: fan_in,
          ratios: ratios
        }
      end
    )
  end

  @doc """
  Find critical dependency paths between two modules.

  Identifies all paths between source and target modules, useful for
  understanding dependency chains and potential impact analysis.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> paths = ElixirScope.Graph.Algorithms.DependencyAnalysis.dependency_paths(graph, :a, :b)
      iex> is_list(paths)
      true
  """
  @spec dependency_paths(graph(), vertex(), vertex()) :: [dependency_chain()]
  def dependency_paths(dependency_graph, source, target) do
    FoundationIntegration.measure_algorithm(
      :dependency_paths,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph),
        source: source,
        target: target
      },
      fn ->
        # Find all paths from source to target
        case Graph.get_paths(dependency_graph, source, target) do
          [] ->
            []

          paths ->
            # Sort paths by length and importance
            paths
            |> Enum.sort_by(&length/1)
            # Limit to top 10 paths to avoid explosion
            |> Enum.take(10)
        end
      end
    )
  end

  @doc """
  Identify dependency bottlenecks in the system.

  Finds modules that are on many critical paths and could become
  bottlenecks for compilation or development.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> bottlenecks = ElixirScope.Graph.Algorithms.DependencyAnalysis.dependency_bottlenecks(graph)
      iex> is_map(bottlenecks)
      true
  """
  @spec dependency_bottlenecks(graph()) :: %{vertex() => float()}
  def dependency_bottlenecks(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :dependency_bottlenecks,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        # Use betweenness centrality as a proxy for bottlenecks
        betweenness = calculate_simple_betweenness_centrality(dependency_graph)

        # Enhance with dependency-specific metrics
        patterns = dependency_patterns(dependency_graph)

        # Combine betweenness with fan-in to identify true bottlenecks
        vertices = Graph.vertices(dependency_graph)

        Enum.reduce(vertices, %{}, fn vertex, acc ->
          betweenness_score = Map.get(betweenness, vertex, 0.0)
          fan_in_score = Map.get(patterns.fan_in, vertex, 0)

          # Normalize fan-in score
          max_fan_in = Map.values(patterns.fan_in) |> Enum.max(fn -> 1 end)
          normalized_fan_in = fan_in_score / max_fan_in

          # Combined bottleneck score
          bottleneck_score = betweenness_score * 0.7 + normalized_fan_in * 0.3
          Map.put(acc, vertex, bottleneck_score)
        end)
      end
    )
  end

  @doc """
  Analyze dependency layers and architectural structure.

  Partitions the dependency graph into layers based on dependency depth,
  revealing architectural structure and potential layering violations.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> {:ok, layers} = ElixirScope.Graph.Algorithms.DependencyAnalysis.dependency_layers(graph)
      iex> is_list(layers)
      true
  """
  @spec dependency_layers(graph()) :: {:ok, [[vertex()]]} | {:error, :cyclic}
  def dependency_layers(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :dependency_layers,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        case Graph.is_acyclic?(dependency_graph) do
          false -> {:error, :cyclic}
          true -> {:ok, compute_dependency_layers(dependency_graph)}
        end
      end
    )
  end

  @doc """
  Calculate dependency stability metrics for each module.

  Measures how stable each module is based on its dependency patterns.
  Stable modules have high fan-in and low fan-out.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> stability = ElixirScope.Graph.Algorithms.DependencyAnalysis.dependency_stability(graph)
      iex> is_map(stability)
      true
  """
  @spec dependency_stability(graph()) :: %{vertex() => float()}
  def dependency_stability(dependency_graph) do
    FoundationIntegration.measure_algorithm(
      :dependency_stability,
      %{
        nodes: Graph.num_vertices(dependency_graph),
        edges: Graph.num_edges(dependency_graph)
      },
      fn ->
        patterns = dependency_patterns(dependency_graph)
        vertices = Graph.vertices(dependency_graph)

        Enum.reduce(vertices, %{}, fn vertex, acc ->
          fan_out = Map.get(patterns.fan_out, vertex, 0)
          fan_in = Map.get(patterns.fan_in, vertex, 0)

          # Martin's stability metric: Instability = Fan-out / (Fan-in + Fan-out)
          # We calculate Stability = 1 - Instability
          total_coupling = fan_in + fan_out
          instability = if total_coupling > 0, do: fan_out / total_coupling, else: 0.0
          stability = 1.0 - instability

          Map.put(acc, vertex, stability)
        end)
      end
    )
  end

  # Private helper functions

  @spec calculate_simple_betweenness_centrality(graph()) :: %{vertex() => float()}
  defp calculate_simple_betweenness_centrality(graph) do
    vertices = Graph.vertices(graph)

    # For small graphs, use simple algorithm
    if length(vertices) <= 50 do
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

  @spec has_self_loop?(graph(), [vertex()]) :: boolean()
  defp has_self_loop?(graph, [vertex]) do
    Graph.edges(graph)
    |> Enum.any?(fn %{v1: v1, v2: v2} -> v1 == vertex and v2 == vertex end)
  end

  defp has_self_loop?(_graph, _component), do: false

  @spec analyze_circular_component(graph(), [vertex()]) :: map()
  defp analyze_circular_component(graph, component) do
    # Extract edges within the component
    component_set = MapSet.new(component)

    internal_edges =
      Graph.edges(graph)
      |> Enum.filter(fn %{v1: v1, v2: v2} ->
        MapSet.member?(component_set, v1) and MapSet.member?(component_set, v2)
      end)

    %{
      modules: component,
      size: length(component),
      internal_edges: length(internal_edges),
      density: calculate_component_density(component, internal_edges)
    }
  end

  @spec calculate_component_density([vertex()], [Graph.Edge.t()]) :: float()
  defp calculate_component_density(component, _edges) when length(component) <= 1, do: 0.0

  defp calculate_component_density(component, edges) do
    n = length(component)
    # Maximum possible edges in directed graph
    max_edges = n * (n - 1)
    actual_edges = length(edges)
    actual_edges / max_edges
  end

  @spec find_longest_paths_in_dag(graph()) :: [dependency_chain()]
  defp find_longest_paths_in_dag(graph) do
    # Use dynamic programming to find longest paths
    case Graph.topsort(graph) do
      false ->
        []

      sorted_vertices ->
        # Calculate longest distance to each vertex
        distances = calculate_longest_distances(graph, sorted_vertices)

        # Find vertices with maximum distance
        max_distance = Map.values(distances) |> Enum.max(fn -> 0 end)

        end_vertices =
          Enum.filter(Map.keys(distances), fn v ->
            Map.get(distances, v, 0) == max_distance
          end)

        # Reconstruct longest paths
        Enum.flat_map(end_vertices, fn end_vertex ->
          reconstruct_longest_paths(graph, distances, end_vertex)
        end)
        |> Enum.uniq()
    end
  end

  @spec calculate_longest_distances(graph(), [vertex()]) :: %{vertex() => integer()}
  defp calculate_longest_distances(graph, sorted_vertices) do
    # Initialize distances
    initial_distances = Enum.reduce(sorted_vertices, %{}, fn v, acc -> Map.put(acc, v, 0) end)

    # Process vertices in topological order
    Enum.reduce(sorted_vertices, initial_distances, fn vertex, distances ->
      current_distance = Map.get(distances, vertex, 0)

      # Update distances to all neighbors
      Graph.out_neighbors(graph, vertex)
      |> Enum.reduce(distances, fn neighbor, acc ->
        new_distance = current_distance + 1
        current_neighbor_distance = Map.get(acc, neighbor, 0)

        if new_distance > current_neighbor_distance do
          Map.put(acc, neighbor, new_distance)
        else
          acc
        end
      end)
    end)
  end

  @spec reconstruct_longest_paths(graph(), %{vertex() => integer()}, vertex()) :: [
          dependency_chain()
        ]
  defp reconstruct_longest_paths(graph, distances, end_vertex) do
    target_distance = Map.get(distances, end_vertex, 0)
    find_paths_to_vertex(graph, distances, end_vertex, target_distance, [])
  end

  @spec find_paths_to_vertex(graph(), %{vertex() => integer()}, vertex(), integer(), [vertex()]) ::
          [dependency_chain()]
  defp find_paths_to_vertex(_graph, _distances, vertex, 0, current_path) do
    [[vertex | current_path]]
  end

  defp find_paths_to_vertex(graph, distances, vertex, target_distance, current_path) do
    # Find predecessors that could be on a longest path
    predecessors =
      Graph.in_neighbors(graph, vertex)
      |> Enum.filter(fn pred -> Map.get(distances, pred, 0) == target_distance - 1 end)

    if Enum.empty?(predecessors) do
      [[vertex | current_path]]
    else
      Enum.flat_map(predecessors, fn pred ->
        find_paths_to_vertex(graph, distances, pred, target_distance - 1, [vertex | current_path])
      end)
    end
  end

  @spec compute_dependency_layers(graph()) :: [[vertex()]]
  defp compute_dependency_layers(graph) do
    remaining_graph = graph
    layers = []

    compute_layers_iteratively(remaining_graph, layers)
  end

  @spec compute_layers_iteratively(graph(), [[vertex()]]) :: [[vertex()]]
  defp compute_layers_iteratively(graph, layers) do
    vertices = Graph.vertices(graph)

    if Enum.empty?(vertices) do
      Enum.reverse(layers)
    else
      # Find vertices with no incoming edges (current layer)
      current_layer =
        Enum.filter(vertices, fn vertex ->
          Graph.in_degree(graph, vertex) == 0
        end)

      if Enum.empty?(current_layer) do
        # This shouldn't happen in an acyclic graph
        Enum.reverse(layers)
      else
        # Remove current layer vertices and continue
        updated_graph =
          Enum.reduce(current_layer, graph, fn vertex, acc ->
            Graph.delete_vertex(acc, vertex)
          end)

        compute_layers_iteratively(updated_graph, [current_layer | layers])
      end
    end
  end
end
