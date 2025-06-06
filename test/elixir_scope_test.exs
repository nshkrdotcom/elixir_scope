defmodule ElixirScopeTest do
  use ExUnit.Case
  doctest ElixirScope

  test "version returns correct version" do
    assert "0.1.0" = ElixirScope.version()
  end

  test "layers returns all expected layers" do
    expected = [:ast, :graph, :cpg, :analysis, :capture, :query, :intelligence, :debugger]
    assert expected == ElixirScope.layers()
  end
end
