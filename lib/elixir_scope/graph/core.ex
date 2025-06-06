defmodule ElixirScope.Graph.Core do
  @moduledoc """
  Core libgraph integration with Foundation telemetry and configuration.

  This module provides the fundamental graph operations using libgraph as the underlying
  implementation, while integrating with ElixirScope's Foundation layer for telemetry,
  configuration, and performance monitoring.
  """

  alias ElixirScope.Graph.FoundationIntegration

  @type graph :: Graph.t()
  @type vertex :: term()
  @type edge :: Graph.Edge.t()
  @type path :: [vertex()]
  @type distance :: number() | :infinity

  @doc """
  Create a new graph with the specified type.

  ## Options
  - `:directed` - Creates a directed graph (default)
  - `:undirected` - Creates an undirected graph

  ## Examples

      iex> ElixirScope.Graph.Core.new_graph()
      %Graph{type: :directed, ...}

      iex> ElixirScope.Graph.Core.new_graph(:undirected)
      %Graph{type: :undirected, ...}
  """
  @spec new_graph(atom()) :: graph()
  def new_graph(type \\ :directed) do
    FoundationIntegration.emit_metrics(:graph_created, %{type: type})

    case type do
      :directed -> Graph.new(type: :directed)
      :undirected -> Graph.new(type: :undirected)
      _ -> raise ArgumentError, "Invalid graph type: #{type}. Must be :directed or :undirected"
    end
  end

  @doc """
  Find shortest path between two vertices with telemetry integration.

  Uses Dijkstra's algorithm from libgraph and emits performance metrics
  via Foundation telemetry services.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Core.shortest_path_with_telemetry(graph, :a, :b)
      {:ok, [:a, :b]}

      iex> empty_graph = Graph.new()
      iex> ElixirScope.Graph.Core.shortest_path_with_telemetry(empty_graph, :a, :b)
      {:error, :no_path}
  """
  @spec shortest_path_with_telemetry(graph(), vertex(), vertex()) ::
          {:ok, path()} | {:error, :no_path}
  def shortest_path_with_telemetry(graph, source, target) do
    FoundationIntegration.measure_algorithm(
      :shortest_path,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        case safe_dijkstra(graph, source, target) do
          [] -> {:error, :no_path}
          path -> {:ok, path}
        end
      end
    )
  end

  @doc """
  Calculate centrality measures with configuration from Foundation.

  Supports multiple centrality algorithms with configurable parameters
  from Foundation's configuration system.

  ## Centrality Types
  - `:betweenness` - Betweenness centrality
  - `:closeness` - Closeness centrality
  - `:degree` - Degree centrality

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Core.centrality_with_config(graph, :degree)
      %{a: 1.0, b: 1.0}
  """
  @spec centrality_with_config(graph(), atom()) :: %{vertex() => float()}
  def centrality_with_config(graph, centrality_type) do
    FoundationIntegration.measure_algorithm(
      :centrality,
      %{
        type: centrality_type,
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        case centrality_type do
          :betweenness ->
            calculate_betweenness_centrality(graph)

          :closeness ->
            calculate_closeness_centrality(graph)

          :degree ->
            calculate_degree_centrality(graph)

          _ ->
            raise ArgumentError, "Unsupported centrality type: #{centrality_type}"
        end
      end
    )
  end

  # Private helper functions for centrality calculations

  # Wrapper to handle libgraph version differences
  @spec safe_dijkstra(graph(), vertex(), vertex()) :: [vertex()]
  defp safe_dijkstra(graph, source, target) do
    result = Graph.dijkstra(graph, source, target)
    if is_list(result), do: result, else: []
  end

  @spec calculate_betweenness_centrality(graph()) :: %{vertex() => float()}
  defp calculate_betweenness_centrality(graph) do
    vertices = Graph.vertices(graph)
    vertex_count = length(vertices)

    if vertex_count <= 2 do
      # For graphs with 2 or fewer vertices, betweenness is always 0
      Map.new(vertices, fn v -> {v, 0.0} end)
    else
      # Initialize centrality scores
      centrality = Map.new(vertices, fn v -> {v, 0.0} end)

      # For each pair of vertices
      Enum.reduce(vertices, centrality, fn source, acc ->
        Enum.reduce(vertices, acc, fn target, inner_acc ->
          if source != target do
            paths = Graph.get_paths(graph, source, target)

            if length(paths) > 0 do
              # Count how many shortest paths go through each vertex
              _path_count = length(paths)
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
    end
  end

  @spec calculate_closeness_centrality(graph()) :: %{vertex() => float()}
  defp calculate_closeness_centrality(graph) do
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

  @spec calculate_degree_centrality(graph()) :: %{vertex() => float()}
  defp calculate_degree_centrality(graph) do
    vertices = Graph.vertices(graph)
    vertex_count = length(vertices)
    max_possible_degree = if vertex_count > 1, do: vertex_count - 1, else: 1

    Map.new(vertices, fn vertex ->
      degree = Graph.degree(graph, vertex)
      normalized_degree = degree / max_possible_degree
      {vertex, normalized_degree}
    end)
  end

  @doc """
  Find strongly connected components with performance measurement.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Core.connected_components_measured(graph)
      [[:a], [:b]]
  """
  @spec connected_components_measured(graph()) :: [[vertex()]]
  def connected_components_measured(graph) do
    FoundationIntegration.measure_algorithm(
      :connected_components,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        Graph.components(graph)
      end
    )
  end

  @doc """
  Perform topological sort with telemetry.

  Assumes input graph is a directed acyclic graph (DAG).

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Core.topological_sort_measured(graph)
      {:ok, [:a, :b]}
  """
  @spec topological_sort_measured(graph()) :: {:ok, [vertex()]} | {:error, :cyclic}
  def topological_sort_measured(graph) do
    FoundationIntegration.measure_algorithm(
      :topological_sort,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        case Graph.topsort(graph) do
          false -> {:error, :cyclic}
          sorted_vertices when is_list(sorted_vertices) -> {:ok, sorted_vertices}
        end
      end
    )
  end

  @doc """
  Check if the graph has cycles with performance monitoring.

  ## Examples

      iex> acyclic_graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Core.is_acyclic_measured(acyclic_graph)
      true
  """
  @spec is_acyclic_measured(graph()) :: boolean()
  def is_acyclic_measured(graph) do
    FoundationIntegration.measure_algorithm(
      :cycle_detection,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph)
      },
      fn ->
        Graph.is_acyclic?(graph)
      end
    )
  end

  @doc """
  Find all paths between two vertices with length limit.

  ## Examples

      iex> graph = Graph.new() |> Graph.add_vertex(:a) |> Graph.add_vertex(:b) |> Graph.add_edge(:a, :b)
      iex> ElixirScope.Graph.Core.all_paths_measured(graph, :a, :b, 3)
      [[:a, :b]]
  """
  @spec all_paths_measured(graph(), vertex(), vertex(), non_neg_integer()) :: [path()]
  def all_paths_measured(graph, source, target, max_length) do
    FoundationIntegration.measure_algorithm(
      :all_paths,
      %{
        nodes: Graph.num_vertices(graph),
        edges: Graph.num_edges(graph),
        max_length: max_length
      },
      fn ->
        Graph.get_paths(graph, source, target)
        |> Enum.filter(&(length(&1) <= max_length))
      end
    )
  end
end
