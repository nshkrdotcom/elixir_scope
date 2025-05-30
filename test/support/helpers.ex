# ORIG_FILE
defmodule ElixirScope.Test.Support.Helpers do
  @moduledoc """
  Main test helper module with utility functions for testing.
  """
  
  alias ElixirScope.Test.Support.{Generators, Assertions, Setup}
  
  def setup_test_environment do
    Setup.initialize_test_environment()
  end
  
  def generate_sample_ast(type \\ :simple) do
    Generators.generate_ast(type)
  end
  
  def generate_sample_cpg(type \\ :basic) do
    Generators.generate_cpg(type)
  end
  
  def assert_cpg_structure(cpg, expected_structure) do
    Assertions.assert_cpg_structure(cpg, expected_structure)
  end
  
  def assert_graph_properties(graph, properties) do
    Assertions.assert_graph_properties(graph, properties)
  end
end
