defmodule ElixirScope.Foundation.Error do
  @moduledoc """
  Standardized error handling for ElixirScope Foundation layer.

  Provides consistent error formats, structured error handling, and
  comprehensive error classification following enterprise patterns.
  """

  @type error_code :: atom()
  @type error_context :: map()
  @type stacktrace_info :: [map()]

  @type t :: %__MODULE__{
    code: error_code(),
    message: String.t(),
    context: error_context(),
    module: module() | nil,
    function: atom() | nil,
    line: non_neg_integer() | nil,
    stacktrace: stacktrace_info() | nil,
    timestamp: DateTime.t(),
    correlation_id: String.t() | nil
  }

  defstruct [
    :code,
    :message,
    :context, # : %{},  # Always initialize as map
    :module,
    :function,
    :line,
    :stacktrace,
    :timestamp,
    :correlation_id
  ]

  ## Error Categories

  # Configuration Errors
  @config_errors [
    :invalid_config_structure,
    :invalid_config_value,
    :missing_required_config,
    :config_validation_failed,
    :config_not_found,
    :config_update_forbidden
  ]

  # Validation Errors
  @validation_errors [
    :invalid_input,
    :validation_failed,
    :constraint_violation,
    :type_mismatch,
    :range_error,
    :format_error
  ]

  # System Errors
  @system_errors [
    :initialization_failed,
    :service_unavailable,
    :timeout,
    :resource_exhausted,
    :dependency_failed,
    :internal_error,
    :external_error,
    :test_error
  ]

  # Data Errors
  @data_errors [
    :data_corruption,
    :serialization_failed,
    :deserialization_failed,
    :data_not_found,
    :data_conflict
  ]

  @all_error_codes @config_errors ++ @validation_errors ++ @system_errors ++ @data_errors

  ## Public API

  @doc """
  Creates a new standardized error.
  """
  @spec new(error_code(), String.t(), keyword()) :: t()
  def new(code, message, opts \\ []) when code in @all_error_codes do
    %__MODULE__{
      code: code,
      message: message,
      context: Keyword.get(opts, :context, %{}),
      module: Keyword.get(opts, :module),
      function: Keyword.get(opts, :function),
      line: Keyword.get(opts, :line),
      stacktrace: format_stacktrace(Keyword.get(opts, :stacktrace)),
      timestamp: DateTime.utc_now(),
      correlation_id: Keyword.get(opts, :correlation_id)
    }
  end

  ## Convenience Constructors

  @spec config_error(
    :config_not_found | :config_update_forbidden | :config_validation_failed |
    :invalid_config_structure | :invalid_config_value | :missing_required_config,
    String.t(),
    keyword()
  ) :: t()
  def config_error(subcode, message, opts \\ [])
    when subcode in @config_errors do
    new(subcode, message, opts)
  end

  @spec validation_error(
    :constraint_violation | :format_error | :invalid_input |
    :range_error | :type_mismatch | :validation_failed,
    String.t(),
    keyword()
  ) :: t()
  def validation_error(subcode, message, opts \\ [])
    when subcode in @validation_errors do
    new(subcode, message, opts)
  end

  @spec system_error(
    :dependency_failed | :initialization_failed | :internal_error |
    :resource_exhausted | :service_unavailable | :timeout,
    String.t(),
    keyword()
  ) :: t()
  def system_error(subcode, message, opts \\ [])
    when subcode in @system_errors do
    new(subcode, message, opts)
  end

  @spec data_error(
    :data_conflict | :data_corruption | :data_not_found |
    :deserialization_failed | :serialization_failed,
    String.t(),
    keyword()
  ) :: t()
  def data_error(subcode, message, opts \\ [])
    when subcode in @data_errors do
    new(subcode, message, opts)
  end

  ## Error Result Helpers

  @spec error_result(t()) :: {:error, t()}
  def error_result(%__MODULE__{} = error), do: {:error, error}

  @spec error_result(error_code(), String.t(), keyword()) :: {:error, t()}
  def error_result(code, message, opts \\ []) do
    {:error, new(code, message, opts)}
  end

  ## Error Inspection and Conversion

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = error) do
    Map.from_struct(error)
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = error) do
    base = "[#{error.code}] #{error.message}"

    case error.context do
      context when map_size(context) > 0 ->
        context_str = inspect(context, pretty: true, limit: 3)
        "#{base} (context: #{context_str})"
      _ ->
        base
    end
  end

  @spec severity(t()) :: :low | :medium | :high | :critical
  def severity(%__MODULE__{code: code}) do
    cond do
      code in @system_errors -> :critical
      code in @config_errors -> :high
      code in @data_errors -> :medium
      code in @validation_errors -> :low
    end
  end

  ## Private Helpers

  defp format_stacktrace(nil), do: nil
  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> Enum.take(10)  # Limit stacktrace depth
    |> Enum.map(&format_stacktrace_entry/1)
  end

  defp format_stacktrace_entry({module, function, arity, location}) do
    %{
      module: module,
      function: function,
      arity: arity,
      file: Keyword.get(location, :file),
      line: Keyword.get(location, :line)
    }
  end
  defp format_stacktrace_entry(entry), do: inspect(entry)
end
