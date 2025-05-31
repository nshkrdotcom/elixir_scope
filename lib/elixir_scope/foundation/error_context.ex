defmodule ElixirScope.Foundation.ErrorContext do
  @moduledoc """
  Enhanced error context system with proper propagation and debugging support.

  Phase 1 Implementation:
  - Nested context support with breadcrumbs
  - Operation tracking and correlation
  - Emergency context recovery
  - Enhanced error propagation patterns
  """

  alias ElixirScope.Foundation.{Error, Utils}

  defstruct [
    # Unique ID for this operation
    :operation_id,
    # Module where operation started
    :module,
    # Function where operation started
    :function,
    # Cross-system correlation
    :correlation_id,
    # When operation began
    :start_time,
    # Additional context data
    :metadata,
    # Operation trail
    :breadcrumbs,
    # Nested context support
    :parent_context
  ]

  @type t :: %__MODULE__{
          operation_id: pos_integer(),
          module: module(),
          function: atom(),
          correlation_id: String.t(),
          start_time: integer(),
          metadata: map(),
          breadcrumbs: [breadcrumb()],
          parent_context: t() | nil
        }

  @type context :: t()

  @type breadcrumb :: %{
          module: module(),
          function: atom(),
          timestamp: integer(),
          metadata: map()
        }

  ## Context Creation and Management

  def new(module, function, opts \\ []) do
    %__MODULE__{
      operation_id: Utils.generate_id(),
      module: module,
      function: function,
      correlation_id: Keyword.get(opts, :correlation_id, Utils.generate_correlation_id()),
      start_time: Utils.monotonic_timestamp(),
      metadata: Keyword.get(opts, :metadata, %{}),
      breadcrumbs: [
        %{
          module: module,
          function: function,
          timestamp: Utils.monotonic_timestamp(),
          metadata: %{}
        }
      ],
      parent_context: Keyword.get(opts, :parent_context)
    }
  end

  def child_context(%__MODULE__{} = parent, module, function, metadata \\ %{}) do
    %__MODULE__{
      operation_id: Utils.generate_id(),
      module: module,
      function: function,
      correlation_id: parent.correlation_id,
      start_time: Utils.monotonic_timestamp(),
      metadata: Map.merge(parent.metadata, metadata),
      breadcrumbs:
        parent.breadcrumbs ++
          [
            %{
              module: module,
              function: function,
              timestamp: Utils.monotonic_timestamp(),
              metadata: metadata
            }
          ],
      parent_context: parent
    }
  end

  def add_breadcrumb(%__MODULE__{} = context, module, function, metadata \\ %{}) do
    breadcrumb = %{
      module: module,
      function: function,
      timestamp: Utils.monotonic_timestamp(),
      metadata: metadata
    }

    %{context | breadcrumbs: context.breadcrumbs ++ [breadcrumb]}
  end

  def add_metadata(%__MODULE__{} = context, new_metadata) when is_map(new_metadata) do
    %{context | metadata: Map.merge(context.metadata, new_metadata)}
  end

  ## Error Context Integration

  def with_context(%__MODULE__{} = context, fun) when is_function(fun, 0) do
    # Store context in process dictionary for emergency access
    Process.put(:error_context, context)

    try do
      result = fun.()

      # Clean up and enhance successful results with context
      Process.delete(:error_context)
      enhance_result_with_context(result, context)
    rescue
      exception ->
        # Capture and enhance exception with full context
        enhanced_error = create_exception_error(exception, context, __STACKTRACE__)

        # Clean up
        Process.delete(:error_context)

        # Emit error telemetry
        Error.collect_error_metrics(enhanced_error)

        {:error, enhanced_error}
    end
  end

  def enhance_error(%Error{} = error, %__MODULE__{} = context) do
    # Enhance existing error with additional context
    enhanced_context =
      Map.merge(error.context, %{
        operation_context: %{
          operation_id: context.operation_id,
          correlation_id: context.correlation_id,
          breadcrumbs: context.breadcrumbs,
          duration_ns: Utils.monotonic_timestamp() - context.start_time,
          metadata: context.metadata
        }
      })

    %{
      error
      | context: enhanced_context,
        correlation_id: error.correlation_id || context.correlation_id
    }
  end

  def enhance_error({:error, %Error{} = error}, %__MODULE__{} = context) do
    {:error, enhance_error(error, context)}
  end

  def enhance_error({:error, reason}, %__MODULE__{} = context) do
    # Convert raw error to structured error with context
    error =
      Error.new(:external_error, "External operation failed",
        context: %{
          original_reason: reason,
          operation_context: %{
            operation_id: context.operation_id,
            correlation_id: context.correlation_id,
            breadcrumbs: context.breadcrumbs,
            duration_ns: Utils.monotonic_timestamp() - context.start_time
          }
        },
        correlation_id: context.correlation_id
      )

    {:error, error}
  end

  def enhance_error(result, _context), do: result

  ## Context Recovery and Debugging

  def get_current_context do
    # Emergency context retrieval from process dictionary
    Process.get(:error_context)
  end

  def format_breadcrumbs(%__MODULE__{breadcrumbs: breadcrumbs}) do
    Enum.map_join(breadcrumbs, " -> ", fn %{module: mod, function: func, timestamp: ts} ->
      relative_time = Utils.monotonic_timestamp() - ts
      "#{mod}.#{func} (#{Utils.format_duration(relative_time)} ago)"
    end)
  end

  def get_operation_duration(%__MODULE__{start_time: start_time}) do
    Utils.monotonic_timestamp() - start_time
  end

  ## Enhanced Error Context Integration

  @doc """
  Add context to an existing error or create a new one.
  Enhanced version with better error chaining and context preservation.
  """
  def add_context(result, context, additional_info \\ %{})

  def add_context(:ok, _context, _additional_info), do: :ok
  def add_context({:ok, _} = success, _context, _additional_info), do: success

  def add_context({:error, %Error{} = error}, %__MODULE__{} = context, additional_info) do
    enhanced_error = enhance_error(error, context)
    additional_context = Map.merge(enhanced_error.context, additional_info)
    {:error, %{enhanced_error | context: additional_context}}
  end

  def add_context({:error, %Error{} = error}, context, additional_info) when is_map(context) do
    # Handle legacy map-based context
    updated_context = Map.merge(error.context, Map.merge(context, additional_info))
    {:error, %{error | context: updated_context}}
  end

  def add_context({:error, reason}, %__MODULE__{} = context, additional_info) do
    full_context =
      Map.merge(additional_info, %{
        original_reason: reason,
        operation_context: %{
          operation_id: context.operation_id,
          correlation_id: context.correlation_id,
          breadcrumbs: context.breadcrumbs,
          duration_ns: get_operation_duration(context),
          metadata: context.metadata
        }
      })

    {:error, Error.new(:external_error, "External operation failed", context: full_context)}
  end

  def add_context({:error, reason}, context, additional_info) when is_map(context) do
    # Handle legacy map-based context
    full_context = Map.merge(context, Map.merge(additional_info, %{original_reason: reason}))
    {:error, Error.new(:external_error, "External operation failed", context: full_context)}
  end

  ## Private Helpers

  defp enhance_result_with_context(result, context) do
    # For successful results, we might want to add telemetry
    duration = get_operation_duration(context)

    ElixirScope.Foundation.Telemetry.emit_gauge(
      [:foundation, :operations, :duration],
      duration,
      %{
        module: context.module,
        function: context.function,
        correlation_id: context.correlation_id
      }
    )

    result
  end

  defp create_exception_error(exception, context, stacktrace) do
    Error.new(:internal_error, "Exception in operation: #{Exception.message(exception)}",
      context: %{
        exception_type: exception.__struct__,
        exception_message: Exception.message(exception),
        operation_context: %{
          operation_id: context.operation_id,
          correlation_id: context.correlation_id,
          breadcrumbs: context.breadcrumbs,
          duration_ns: get_operation_duration(context),
          metadata: context.metadata
        }
      },
      correlation_id: context.correlation_id,
      stacktrace: format_stacktrace(stacktrace)
    )
  end

  defp format_stacktrace(stacktrace) do
    stacktrace
    # Limit depth
    |> Enum.take(10)
    |> Enum.map(fn
      {module, function, arity, location} ->
        %{
          module: module,
          function: function,
          arity: arity,
          file: Keyword.get(location, :file),
          line: Keyword.get(location, :line)
        }

      entry ->
        %{raw: inspect(entry)}
    end)
  end
end
