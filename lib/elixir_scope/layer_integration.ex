defmodule ElixirScope.LayerIntegration do
  @moduledoc """
  Integration module for coordinating between the 9 layers.
  
  This module provides the main API for cross-layer communication
  and ensures proper dependency flow between layers.
  """
  
  alias ElixirScope.{Foundation, AST, Graph, CPG, Analysis, Query, Capture, Intelligence, Debugger}
  
  @doc """
  Initialize all layers in proper dependency order.
  """
  def initialize_layers(opts \\ []) do
    with {:ok, _} <- Foundation.start_link(opts),
         {:ok, _} <- AST.initialize(opts),
         {:ok, _} <- Graph.initialize(opts),
         {:ok, _} <- CPG.initialize(opts),
         {:ok, _} <- Analysis.initialize(opts),
         {:ok, _} <- Query.initialize(opts),
         {:ok, _} <- Capture.initialize(opts),
         {:ok, _} <- Intelligence.initialize(opts),
         {:ok, _} <- Debugger.initialize(opts) do
      {:ok, :all_layers_initialized}
    else
      error -> {:error, {:layer_initialization_failed, error}}
    end
  end
  
  @doc """
  Coordinate a full analysis workflow across all layers.
  """
  def full_analysis_workflow(module_or_file, opts \\ []) do
    with {:ok, ast_data} <- AST.parse_and_store(module_or_file),
         {:ok, cpg_data} <- CPG.build_from_ast(ast_data),
         {:ok, analysis_results} <- Analysis.analyze_cpg(cpg_data),
         {:ok, enhanced_results} <- Intelligence.enhance_analysis(analysis_results) do
      {:ok, %{
        ast: ast_data,
        cpg: cpg_data,
        analysis: analysis_results,
        intelligence: enhanced_results
      }}
    else
      error -> {:error, {:workflow_failed, error}}
    end
  end
  
  @doc """
  Start an enhanced debugging session.
  """
  def start_enhanced_debugging(target, opts \\ []) do
    with {:ok, session_id} <- Debugger.create_session(target, opts),
         {:ok, _} <- Capture.start_capture_for_session(session_id),
         {:ok, _} <- Intelligence.enable_ai_assistance(session_id) do
      {:ok, session_id}
    else
      error -> {:error, {:debugging_session_failed, error}}
    end
  end
end
