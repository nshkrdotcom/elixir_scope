defmodule ElixirScope.Foundation.Error do
  @moduledoc """
  Enhanced error handling with hierarchical error codes and comprehensive error management.

  Phase 1 Implementation:
  - Hierarchical error code system (C000-C999, S000-S999, etc.)
  - Enhanced error context and recovery strategies
  - Standardized error propagation patterns
  - Error metrics and analysis capabilities
  """

  @type error_code :: atom()
  @type error_context :: map()
  @type stacktrace_info :: [map()]
  @type error_category :: :config | :system | :data | :external
  @type error_subcategory :: :structure | :validation | :access | :runtime
  @type error_severity :: :low | :medium | :high | :critical
  @type retry_strategy :: :no_retry | :immediate | :fixed_delay | :exponential_backoff

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

  # # Hierarchical Error Code System
  # @error_categories %{
  #   # Configuration errors (C000-C999)
  #   config: %{
  #     base_code: 1000,
  #     subcodes: %{
  #       structure: 100,    # C100-C199: Structure issues
  #       validation: 200,   # C200-C299: Validation failures
  #       access: 300,       # C300-C399: Access/permission issues
  #       runtime: 400       # C400-C499: Runtime update issues
  #     }
  #   },

  #   # System errors (S000-S999)
  #   system: %{
  #     base_code: 2000,
  #     subcodes: %{
  #       initialization: 100,  # S100-S199: Startup failures
  #       resources: 200,       # S200-S299: Resource exhaustion
  #       dependencies: 300,    # S300-S399: Dependency failures
  #       runtime: 400          # S400-S499: Runtime system errors
  #     }
  #   },

  #   # Data errors (D000-D999)
  #   data: %{
  #     base_code: 3000,
  #     subcodes: %{
  #       serialization: 100,   # D100-D199: Serialization issues
  #       validation: 200,      # D200-D299: Data validation
  #       corruption: 300,      # D300-D399: Data corruption
  #       not_found: 400        # D400-D499: Missing data
  #     }
  #   },

  #   # External errors (E000-E999)
  #   external: %{
  #     base_code: 4000,
  #     subcodes: %{
  #       network: 100,         # E100-E199: Network issues
  #       service: 200,         # E200-E299: External service failures
  #       timeout: 300,         # E300-E399: Timeout issues
  #       auth: 400            # E400-E499: Authentication failures
  #     }
  #   }
  # }

  @error_definitions %{
    # Configuration Errors
    {:config, :structure, :invalid_config_structure} =>
      {1101, :high, "Configuration structure is invalid"},
    {:config, :structure, :missing_required_field} =>
      {1102, :high, "Required configuration field missing"},
    {:config, :validation, :invalid_config_value} =>
      {1201, :medium, "Configuration value failed validation"},
    {:config, :validation, :constraint_violation} =>
      {1202, :medium, "Configuration constraint violated"},
    {:config, :validation, :range_error} => {1203, :low, "Value outside acceptable range"},
    {:config, :access, :config_not_found} => {1301, :high, "Configuration not found"},
    {:config, :runtime, :config_update_forbidden} =>
      {1401, :medium, "Configuration update not allowed"},

    # System Errors
    {:system, :initialization, :initialization_failed} =>
      {2101, :critical, "System initialization failed"},
    {:system, :initialization, :service_unavailable} =>
      {2102, :high, "Required service unavailable"},
    {:system, :resources, :resource_exhausted} => {2201, :high, "System resources exhausted"},
    {:system, :dependencies, :dependency_failed} => {2301, :high, "Required dependency failed"},
    {:system, :runtime, :internal_error} => {2401, :critical, "Internal system error"},

    # Data Errors
    {:data, :serialization, :serialization_failed} => {3101, :medium, "Data serialization failed"},
    {:data, :serialization, :deserialization_failed} =>
      {3102, :medium, "Data deserialization failed"},
    {:data, :validation, :type_mismatch} => {3201, :low, "Data type mismatch"},
    {:data, :validation, :format_error} => {3202, :low, "Data format error"},
    {:data, :corruption, :data_corruption} => {3301, :critical, "Data corruption detected"},
    {:data, :not_found, :data_not_found} => {3401, :low, "Requested data not found"},

    # External Errors
    {:external, :network, :network_error} => {4101, :medium, "Network communication error"},
    {:external, :service, :external_service_error} => {4201, :medium, "External service error"},
    {:external, :timeout, :timeout} => {4301, :medium, "Operation timeout"},
    {:external, :auth, :authentication_failed} => {4401, :high, "Authentication failed"},

    # Validation-specific errors
    {:data, :validation, :validation_failed} => {3203, :medium, "Data validation failed"},
    {:data, :validation, :invalid_input} => {3204, :low, "Invalid input provided"}
  }

  ## Error Creation API

  def new(error_type, message \\ nil, opts \\ []) do
    {code, severity, default_message} = get_error_definition(error_type)
    {category, subcategory} = categorize_error(error_type)

    %__MODULE__{
      code: code,
      error_type: error_type,
      message: message || default_message,
      severity: severity,
      context: Keyword.get(opts, :context, %{}),
      correlation_id: Keyword.get(opts, :correlation_id),
      timestamp: DateTime.utc_now(),
      stacktrace: format_stacktrace(Keyword.get(opts, :stacktrace)),
      category: category,
      subcategory: subcategory,
      retry_strategy: determine_retry_strategy(error_type, severity),
      recovery_actions: suggest_recovery_actions(error_type, opts)
    }
  end

  ## Error Result Helpers

  def error_result(error_type, message \\ nil, opts \\ []) do
    {:error, new(error_type, message, opts)}
  end

  def wrap_error(result, error_type, message \\ nil, opts \\ []) do
    case result do
      {:error, existing_error} when is_struct(existing_error, __MODULE__) ->
        # Chain errors while preserving original context
        enhanced_error = %{
          existing_error
          | context:
              Map.merge(existing_error.context, %{
                wrapped_by: error_type,
                wrapper_message: message,
                wrapper_context: Keyword.get(opts, :context, %{})
              })
        }

        {:error, enhanced_error}

      {:error, reason} ->
        # Wrap raw error reasons
        error_result(
          error_type,
          message,
          Keyword.put(
            opts,
            :context,
            Map.merge(
              Keyword.get(opts, :context, %{}),
              %{original_reason: reason}
            )
          )
        )

      other ->
        other
    end
  end

  ## Error Analysis and Recovery

  def is_retryable?(%__MODULE__{retry_strategy: strategy}) do
    strategy != :no_retry
  end

  def retry_delay(%__MODULE__{retry_strategy: :exponential_backoff}, attempt) do
    min(1000 * :math.pow(2, attempt), 30_000) |> round()
  end

  def retry_delay(%__MODULE__{retry_strategy: :fixed_delay}, _attempt), do: 1000
  def retry_delay(%__MODULE__{retry_strategy: :immediate}, _attempt), do: 0
  def retry_delay(%__MODULE__{retry_strategy: :no_retry}, _attempt), do: :infinity

  def should_escalate?(%__MODULE__{severity: severity}) do
    severity in [:high, :critical]
  end

  ## String Representation

  def to_string(%__MODULE__{} = error) do
    base = "[#{error.code}:#{error.error_type}] #{error.message}"

    context_str =
      if map_size(error.context) > 0 do
        " | Context: #{inspect(error.context, limit: 3)}"
      else
        ""
      end

    severity_str = " | Severity: #{error.severity}"

    base <> context_str <> severity_str
  end

  ## Error Metrics Collection

  def collect_error_metrics(%__MODULE__{} = error) do
    # Emit telemetry for error tracking
    ElixirScope.Foundation.Telemetry.emit_counter(
      [:foundation, :errors, error.category, error.subcategory],
      %{
        error_type: error.error_type,
        severity: error.severity,
        code: error.code
      }
    )
  end

  ## Private Implementation

  defp get_error_definition(error_type) do
    # Find the error definition by searching the hierarchy
    Enum.find_value(@error_definitions, {9999, :unknown, "Unknown error"}, fn
      {{_cat, _subcat, ^error_type}, definition} -> definition
      _ -> nil
    end)
  end

  defp categorize_error(error_type) do
    Enum.find_value(@error_definitions, {:unknown, :unknown}, fn
      {{cat, subcat, ^error_type}, _definition} -> {cat, subcat}
      _ -> nil
    end)
  end

  defp determine_retry_strategy(error_type, severity) do
    case {error_type, severity} do
      # Network errors are usually retryable
      {error_type, _} when error_type in [:network_error, :timeout] -> :exponential_backoff
      # Service errors might be retryable
      {:external_service_error, severity} when severity in [:low, :medium] -> :fixed_delay
      # System resource issues might resolve quickly
      {:resource_exhausted, _} -> :immediate
      # Config and data errors usually aren't retryable
      {error_type, _} when error_type in [:invalid_config_value, :data_corruption] -> :no_retry
      # High severity errors generally shouldn't be retried
      {_, :critical} -> :no_retry
      # Default: allow one retry with delay
      _ -> :fixed_delay
    end
  end

  defp suggest_recovery_actions(error_type, opts) do
    base_actions =
      case error_type do
        :invalid_config_value ->
          ["Check configuration format", "Validate against schema", "Review documentation"]

        :service_unavailable ->
          ["Check service health", "Verify network connectivity", "Review service logs"]

        :resource_exhausted ->
          ["Check memory usage", "Review resource limits", "Scale resources if needed"]

        :timeout ->
          ["Increase timeout value", "Check network latency", "Review service performance"]

        _ ->
          ["Check logs for details", "Review error context", "Contact support if needed"]
      end

    # Add context-specific actions
    context_actions =
      case Keyword.get(opts, :context) do
        %{operation: operation} -> ["Review #{operation} implementation"]
        _ -> []
      end

    base_actions ++ context_actions
  end

  defp format_stacktrace(nil), do: nil

  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
    # Limit stacktrace depth
    |> Enum.take(10)
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
