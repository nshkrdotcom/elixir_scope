defmodule ElixirScope.Debugger do
  @moduledoc """
  Debugger Layer - Complete debugging interface and time-travel debugging.

  This layer provides the top-level debugging interface,
  combining all lower layers for comprehensive debugging capabilities.
  """

  @doc """
  Get the current status of the Debugger layer.
  """
  @spec status() :: :ready | :not_implemented
  def status, do: :not_implemented
end
