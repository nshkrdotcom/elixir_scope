defmodule ElixirScope.Foundation.Types.Error do
  @moduledoc """
  Pure data structure for ElixirScope errors.

  Contains structured error information with hierarchical codes,
  context, and recovery suggestions. No business logic - just data.
  """

  @type error_code :: atom()
  @type error_context :: map()
  @type stacktrace_info :: [map()]
  @type error_category :: :config | :system | :data | :external
  @type error_subcategory :: :structure | :validation | :access | :runtime
  @type error_severity :: :low | :medium | :high | :critical
  @type retry_strategy :: :no_retry | :immediate | :fixed_delay | :exponential_backoff

  defstruct [
    :code,
    :error_type,
    :message,
    :severity,
    :context,
    :correlation_id,
    :timestamp,
    :stacktrace,
    :category,
    :subcategory,
    :retry_strategy,
    :recovery_actions
  ]

  @type t :: %__MODULE__{
          code: pos_integer(),
          error_type: error_code(),
          message: String.t(),
          severity: error_severity(),
          context: error_context(),
          correlation_id: String.t() | nil,
          timestamp: DateTime.t(),
          stacktrace: stacktrace_info() | nil,
          category: error_category(),
          subcategory: error_subcategory(),
          retry_strategy: retry_strategy(),
          recovery_actions: [String.t()]
        }

  @doc """
  Create a new error structure.
  """
  @spec new(keyword()) :: t()
  def new(fields \\ []) do
    defaults = [
      timestamp: DateTime.utc_now(),
      context: %{},
      recovery_actions: []
    ]

    struct(__MODULE__, Keyword.merge(defaults, fields))
  end
end
