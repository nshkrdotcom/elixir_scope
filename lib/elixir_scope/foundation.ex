defmodule ElixirScope.Foundation do
  @moduledoc """
  Layer 1: Foundation - Core Infrastructure and Utilities

  ## Responsibilities
  - Provide core utilities for all other layers
  - Manage application-wide configuration
  - Handle event system and telemetry
  - Establish common types and protocols

  ## Dependencies (Allowed)
  - Standard Elixir/OTP libraries only
  - No dependencies on other ElixirScope layers

  ## Dependencies (Forbidden)
  - AST, Graph, CPG, or any higher layers
  - This is the bottom layer - nothing below it

  ## Interface Stability
  - Core utilities: STABLE (comprehensive tests required)
  - Configuration management: STABLE (comprehensive tests required)
  - Event system: STABLE (comprehensive tests required)
  - Telemetry: MEDIUM STABILITY (smoke tests sufficient)
  """

  alias ElixirScope.Foundation.{Error, ErrorContext}

  @doc """
  Initialize the Foundation layer.
  Should be called first before any other ElixirScope components.
  """
  @spec initialize(keyword()) :: :ok | {:error, Error.t()}
  def initialize(opts \\ []) do
    context = ErrorContext.new(__MODULE__, :initialize, metadata: %{opts: opts})

    with :ok <- add_operation_context(
          ElixirScope.Foundation.Config.initialize(opts),
          context,
          :config_initialization
        ),
        :ok <- add_operation_context(
          ElixirScope.Foundation.Events.initialize(),
          context,
          :events_initialization
        ),
        :ok <- add_operation_context(
          ElixirScope.Foundation.Telemetry.initialize(),
          context,
          :telemetry_initialization
        ) do
      :ok
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Get Foundation layer status and health information.
  """
  @spec status() :: %{
    config: :ok | {:error, term()},
    events: :ok | {:error, term()},
    telemetry: :ok | {:error, term()},
    uptime_ms: non_neg_integer()
  }
  def status do
    %{
      config: ElixirScope.Foundation.Config.status(),
      events: ElixirScope.Foundation.Events.status(),
      telemetry: ElixirScope.Foundation.Telemetry.status(),
      uptime_ms: System.monotonic_time(:millisecond)
    }
  end

  # Helper that adds operation context to errors, normalizes success values
  @spec add_operation_context(
    :ok | {:ok, term()} | {:error, Error.t()} | {:error, term()},
    ErrorContext.context(),
    atom()
  ) :: :ok | {:ok, term()} | {:error, Error.t()}
  defp add_operation_context(result, context, operation) do
    ErrorContext.add_context(result, context, %{operation: operation})
  end
end
