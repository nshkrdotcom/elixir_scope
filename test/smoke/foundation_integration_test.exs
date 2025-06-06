defmodule ElixirScope.FoundationIntegrationTest do
  @moduledoc """
  Smoke tests for Foundation layer integration.
  """

  use ExUnit.Case, async: true

  @moduletag :smoke

  test "Foundation dependency is available" do
    assert Code.ensure_loaded?(Foundation)
    assert Code.ensure_loaded?(Foundation.ProcessRegistry)
    assert Code.ensure_loaded?(Foundation.ServiceRegistry)
  end

  test "Application starts successfully" do
    assert {:ok, _pid} = Application.ensure_all_started(:elixir_scope)
  end

  test "Foundation services are accessible" do
    Application.ensure_all_started(:elixir_scope)

    # Test that Foundation modules are available
    assert Code.ensure_loaded?(Foundation.ProcessRegistry)
    assert Code.ensure_loaded?(Foundation.ServiceRegistry)

    # Foundation services should be running from the foundation app
    # We can verify the Foundation app is started
    assert :ok == Application.ensure_started(:foundation)
  end

  test "All layer modules are defined" do
    # Implemented layers
    implemented_layers = [ElixirScope.Graph]

    # Not yet implemented layers
    not_implemented_layers = [
      ElixirScope.AST,
      ElixirScope.CPG,
      ElixirScope.Analysis,
      ElixirScope.Capture,
      ElixirScope.Query,
      ElixirScope.Intelligence,
      ElixirScope.Debugger
    ]

    # Check implemented layers
    for layer <- implemented_layers do
      assert Code.ensure_loaded?(layer)
      assert :ready == layer.status()
    end

    # Check not implemented layers
    for layer <- not_implemented_layers do
      assert Code.ensure_loaded?(layer)
      assert :not_implemented == layer.status()
    end
  end

  test "ElixirScope main module functions" do
    assert "0.1.0" = ElixirScope.version()

    expected_layers = [:ast, :graph, :cpg, :analysis, :capture, :query, :intelligence, :debugger]
    assert expected_layers == ElixirScope.layers()
  end
end
