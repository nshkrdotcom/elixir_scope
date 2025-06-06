defmodule ElixirScope.GraphTest do
  use ExUnit.Case
  doctest ElixirScope.Graph

  alias ElixirScope.Graph

  describe "basic graph operations" do
    test "creates a new directed graph" do
      graph = Graph.new_graph(:directed)

      assert Graph.is_directed?(graph)
      assert Graph.num_vertices(graph) == 0
      assert Graph.num_edges(graph) == 0
    end

    test "creates a new undirected graph" do
      graph = Graph.new_graph(:undirected)

      refute Graph.is_directed?(graph)
      assert Graph.num_vertices(graph) == 0
      assert Graph.num_edges(graph) == 0
    end

    test "raises error for invalid graph type" do
      assert_raise ArgumentError, fn ->
        Graph.new_graph(:invalid)
      end
    end

    test "adds vertices and edges" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_edge(:a, :b)

      assert Graph.num_vertices(graph) == 2
      assert Graph.num_edges(graph) == 1
      assert :a in Graph.vertices(graph)
      assert :b in Graph.vertices(graph)
    end
  end

  describe "shortest path with telemetry" do
    test "finds shortest path between connected vertices" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_vertex(:c)
        |> Graph.add_edge(:a, :b)
        |> Graph.add_edge(:b, :c)

      assert {:ok, [:a, :b, :c]} = Graph.shortest_path_with_telemetry(graph, :a, :c)
    end

    test "returns error when no path exists" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)

      assert {:error, :no_path} = Graph.shortest_path_with_telemetry(graph, :a, :b)
    end

    test "finds direct path when vertices are connected" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_edge(:a, :b)

      assert {:ok, [:a, :b]} = Graph.shortest_path_with_telemetry(graph, :a, :b)
    end
  end

  describe "centrality calculations" do
    test "calculates betweenness centrality" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_vertex(:c)
        |> Graph.add_edge(:a, :b)
        |> Graph.add_edge(:b, :c)

      centrality = Graph.centrality_with_config(graph, :betweenness)

      assert is_map(centrality)
      assert Map.has_key?(centrality, :a)
      assert Map.has_key?(centrality, :b)
      assert Map.has_key?(centrality, :c)
      # :b should have higher centrality as it's on the path between :a and :c
      assert centrality[:b] >= centrality[:a]
    end

    test "calculates closeness centrality" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_edge(:a, :b)

      centrality = Graph.centrality_with_config(graph, :closeness)

      assert is_map(centrality)
      assert Map.has_key?(centrality, :a)
      assert Map.has_key?(centrality, :b)
    end

    test "raises error for unsupported centrality type" do
      graph = Graph.new() |> Graph.add_vertex(:a)

      assert_raise ArgumentError, fn ->
        Graph.centrality_with_config(graph, :unsupported)
      end
    end
  end

  describe "graph analysis" do
    test "analyzes empty graph" do
      graph = Graph.new()

      analysis = Graph.analyze_graph(graph)

      assert analysis.statistics.node_count == 0
      assert analysis.statistics.edge_count == 0
      assert analysis.is_acyclic == true
      assert {:ok, %{valid: true, issues: []}} = analysis.validation
    end

    test "analyzes simple connected graph" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_edge(:a, :b)

      analysis = Graph.analyze_graph(graph)

      assert analysis.statistics.node_count == 2
      assert analysis.statistics.edge_count == 1
      assert analysis.statistics.is_directed == true
      assert analysis.is_acyclic == true
      assert {:ok, sorted} = analysis.topological_sort
      assert :a in sorted
      assert :b in sorted
    end

    test "detects cycles in graph" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_edge(:a, :b)
        |> Graph.add_edge(:b, :a)

      analysis = Graph.analyze_graph(graph)

      assert analysis.is_acyclic == false
      assert {:error, :cyclic} = analysis.topological_sort
    end
  end

  describe "dependency importance" do
    test "calculates dependency importance for simple graph" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:a)
        |> Graph.add_vertex(:b)
        |> Graph.add_vertex(:c)
        |> Graph.add_edge(:a, :b)
        |> Graph.add_edge(:c, :b)

      importance = Graph.dependency_importance(graph)

      assert is_map(importance)
      assert Map.has_key?(importance, :a)
      assert Map.has_key?(importance, :b)
      assert Map.has_key?(importance, :c)
      # :b should have higher importance as it has higher fan-in
      assert importance[:b] >= importance[:a]
      assert importance[:b] >= importance[:c]
    end

    test "handles single vertex graph" do
      graph = Graph.new() |> Graph.add_vertex(:a)

      importance = Graph.dependency_importance(graph)

      assert importance[:a] == 0.0
    end
  end

  describe "status" do
    test "returns :ready status" do
      assert Graph.status() == :ready
    end
  end
end
