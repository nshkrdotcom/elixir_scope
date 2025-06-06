defmodule ElixirScope do
  @moduledoc """
  ElixirScope - AST-based debugging and code intelligence platform.

  ElixirScope implements a clean 8-layer architecture built on top of
  the Foundation layer for enterprise-grade Elixir code analysis and debugging.

  ## Architecture Layers

  ```
  ┌─────────────────────────────────────┐
  │             Debugger                │ ← Complete debugging interface
  ├─────────────────────────────────────┤
  │           Intelligence              │ ← AI/ML integration  
  ├─────────────────────────────────────┤
  │      Capture          Query         │ ← Runtime correlation & querying
  ├─────────────────────────────────────┤
  │            Analysis                 │ ← Architectural analysis
  ├─────────────────────────────────────┤
  │              CPG                    │ ← Code Property Graph
  ├─────────────────────────────────────┤
  │             Graph                   │ ← Graph algorithms
  ├─────────────────────────────────────┤
  │              AST                    │ ← AST parsing & repository
  ├─────────────────────────────────────┤
  │           Foundation                │ ← Core utilities (DEPENDENCY)
  └─────────────────────────────────────┘
  ```

  ## Current Status

  - **Foundation Layer**: Available as hex dependency `foundation ~> 0.1.0`
  - **Upper 8 Layers**: Skeleton structure created, ready for implementation

  ## Quick Start

      # Start the application
      {:ok, _} = Application.ensure_all_started(:elixir_scope)
      
      # Access Foundation services
      registry = Foundation.ProcessRegistry.whereis(:elixir_scope_registry)
      services = Foundation.ServiceRegistry.whereis(:elixir_scope_services)
  """

  @doc """
  Returns the current version of ElixirScope.

  ## Examples

      iex> ElixirScope.version()
      "0.1.0"
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:elixir_scope, :vsn) |> to_string()
  end

  @doc """
  Lists all available layers in the ElixirScope architecture.

  ## Examples

      iex> ElixirScope.layers()
      [:ast, :graph, :cpg, :analysis, :capture, :query, :intelligence, :debugger]
  """
  @spec layers() :: [atom()]
  def layers do
    [:ast, :graph, :cpg, :analysis, :capture, :query, :intelligence, :debugger]
  end
end
