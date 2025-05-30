# Main test helper for ElixirScope enterprise test suite

ExUnit.start()

# Configure ExUnit
ExUnit.configure(
  exclude: [
    :slow,        # Exclude slow tests by default
    :integration, # Exclude integration tests in unit test runs
    :end_to_end,  # Exclude end-to-end tests in unit test runs
    :ai,          # Exclude AI tests (may require API keys)
    :capture,     # Exclude capture tests (may require instrumentation)
    :phoenix,     # Exclude Phoenix tests (may require Phoenix setup)
    :distributed, # Exclude distributed tests (require multiple nodes)
    :real_world,  # Exclude real-world tests (require external projects)
    :benchmark,   # Exclude benchmarks in regular test runs
    :stress,      # Exclude stress tests
    :memory,      # Exclude memory tests
    :scalability, # Exclude scalability tests
    :regression,  # Exclude regression tests
    :scenario     # Exclude scenario tests
  ],
  timeout: 30_000,    # 30 seconds timeout
  max_failures: 10,   # Stop after 10 failures
  trace: false,       # Set to true for detailed output
  capture_log: true   # Capture log output during tests
)

# Load all support modules
Code.require_file("support/helpers.ex", __DIR__)

# Global test setup
defmodule ElixirScope.TestCase do
  @moduledoc """
  Base test case with common setup for all ElixirScope tests.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      alias ElixirScope.Test.Support.Helpers
      alias ElixirScope.Test.Fixtures
      alias ElixirScope.Test.Mocks
      
      import ElixirScope.Test.Support.Assertions.CPGAssertions
      import ElixirScope.Test.Support.Assertions.GraphAssertions
      import ElixirScope.Test.Support.Assertions.PerformanceAssertions
    end
  end
  
  setup do
    # Global test setup
    ElixirScope.Test.Support.Helpers.setup_test_environment()
    
    on_exit(fn ->
      # Global test cleanup
      :ok
    end)
    
    :ok
  end
end

# Configure test environment
Application.put_env(:elixir_scope, :test_mode, true)
Application.put_env(:elixir_scope, :ai_providers, [:mock])
Application.put_env(:elixir_scope, :capture_mode, :test)
