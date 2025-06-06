defmodule ElixirScope.Application do
  @moduledoc """
  ElixirScope Application with Foundation integration.

  This application provides the skeleton for the 8-layer ElixirScope architecture
  built on top of the Foundation layer dependency.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Foundation services are automatically started by the foundation dependency
      # We'll access them via their global names when needed

      # Layer-specific supervisors will be added here as layers are implemented
      # ElixirScope.AST.Supervisor,
      # ElixirScope.Graph.Supervisor,
      # ElixirScope.CPG.Supervisor,
      # ElixirScope.Analysis.Supervisor,
      # ElixirScope.Capture.Supervisor,
      # ElixirScope.Query.Supervisor,
      # ElixirScope.Intelligence.Supervisor,
      # ElixirScope.Debugger.Supervisor,
    ]

    opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
