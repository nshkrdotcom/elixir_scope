defmodule ElixirScope.Foundation.ErrorContext do
  @moduledoc """
  Build rich error context without macros.
  Explicit context building for better debugging.

  # Usage Examples:

  # Example 1: Using explicit function-based approach
  ## note, we removed error handler
  defmodule ElixirScope.Foundation.ExampleExplicit do
    alias ElixirScope.Foundation.{ErrorHandler, Error}

    def initialize(opts) do
      context_opts = [module: __MODULE__, function: :initialize]

      operations = [
        fn -> ElixirScope.Foundation.Config.initialize(opts) end,
        fn -> ElixirScope.Foundation.Events.initialize() end,
        fn -> ElixirScope.Foundation.Telemetry.initialize() end
      ]

      case ErrorHandler.chain(operations, context_opts) do
        :ok -> :ok
        {:ok, _} -> :ok
        {:error, _} = error -> ErrorHandler.normalize_error(error, :initialization_failed, "Foundation initialization failed")
      end
    end
  end

  # Example 2: Using Result type pattern
  defmodule ElixirScope.Foundation.ExampleResult do
    alias ElixirScope.Foundation.{Result, Error}

    def initialize(opts) do
      Result.from_any(ElixirScope.Foundation.Config.initialize(opts))
      |> Result.flat_map(fn _ ->
        Result.from_any(ElixirScope.Foundation.Events.initialize())
      end)
      |> Result.flat_map(fn _ ->
        Result.from_any(ElixirScope.Foundation.Telemetry.initialize())
      end)
      |> Result.map_error(fn error ->
        Error.new(:initialization_failed, "Foundation initialization failed", %{cause: error})
      end)
      |> case do
        {:ok, _} -> :ok
        {:error, _} = error -> error
      end
    end
  end

  # Example 3: Using context-aware approach
  defmodule ElixirScope.Foundation.ExampleContext do
    alias ElixirScope.Foundation.{ErrorContext, Error}

    def initialize(opts) do
      context = ErrorContext.new(__MODULE__, :initialize, metadata: %{opts: opts})

      ErrorContext.with_context(context, fn ->
        with {:ok, _} <- safe_config_init(opts, context),
            :ok <- safe_events_init(context),
            :ok <- safe_telemetry_init(context) do
          :ok
        else
          {:error, _} = error -> error
        end
      end)
    end

    defp safe_config_init(opts, context) do
      case ElixirScope.Foundation.Config.initialize(opts) do
        {:ok, _} = result -> result
        :ok -> {:ok, nil}
        error -> ErrorContext.add_context(error, context, %{operation: :config_init})
      end
    end

    defp safe_events_init(context) do
      case ElixirScope.Foundation.Events.initialize() do
        :ok -> :ok
        error -> ErrorContext.add_context(error, context, %{operation: :events_init})
      end
    end

    defp safe_telemetry_init(context) do
      case ElixirScope.Foundation.Telemetry.initialize() do
        :ok -> :ok
        error -> ErrorContext.add_context(error, context, %{operation: :telemetry_init})
      end
    end
  end
  """

  alias ElixirScope.Foundation.Error

  @type context :: %{
    module: module(),
    function: atom(),
    timestamp: DateTime.t(),
    metadata: map()
  }

  @doc """
  Create an error context for a module/function.
  """
  @spec new(module(), atom(), keyword()) :: context()
  def new(module, function, opts \\ []) do
    %{
      module: module,
      function: function,
      timestamp: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Add context to an existing error or create a new one.
  """
  @spec add_context(
    :ok | {:ok, term()} | {:error, Error.t()} | {:error, term()},
    context(),
    map()
  ) :: :ok | {:ok, term()} | {:error, Error.t()}
  def add_context(result, context, additional_info \\ %{})

  def add_context(:ok, _context, _additional_info), do: :ok
  def add_context({:ok, _} = success, _context, _additional_info), do: success

  def add_context({:error, %Error{} = error}, context, additional_info) do
    updated_context = Map.merge(error.context, Map.merge(context, additional_info))
    {:error, %{error | context: updated_context}}
  end

  def add_context({:error, reason}, context, additional_info) do
    full_context = Map.merge(context, Map.merge(additional_info, %{original_reason: reason}))
    {:error, Error.new(:external_error, "External operation failed", context: full_context)}
  end

  @doc """
  Wrap a function call with context tracking.
  """
  @spec with_context(context(), (() -> term())) :: term()
  def with_context(context, fun) when is_function(fun, 0) do
    try do
      case fun.() do
        {:error, _} = error -> add_context(error, context)
        other -> other
      end
    rescue
      exception ->
        error_context = Map.merge(context, %{
          exception: Exception.message(exception),
          exception_type: exception.__struct__,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })
        {:error, Error.new(:internal_error, "Exception occurred", context: error_context)}
    end
  end
end


# These approaches were not used.

# # Approach 1: Explicit Function-Based Error Handling
# defmodule ElixirScope.Foundation.ErrorHandler do
#   @moduledoc """
#   Explicit, composable error handling utilities.
#   """

#   alias ElixirScope.Foundation.Error
#   require Logger

#   @doc """
#   Wraps a function call with standardized error handling.
#   More explicit than macros, easier to reason about.
#   """
#   @spec safe_call((() -> any()), keyword()) :: any()
#   def safe_call(fun, opts \\ []) when is_function(fun, 0) do
#     try do
#       fun.()
#     rescue
#       error in [ArgumentError, KeyError, MatchError] ->
#         handle_validation_error(error, opts)
#       error in [RuntimeError, FunctionClauseError] ->
#         handle_runtime_error(error, opts)
#       error ->
#         handle_unexpected_error(error, opts)
#     end
#   end

#   @doc """
#   Normalize different error return formats to consistent {:error, Error.t()} format.
#   """
#   @spec normalize_error(any(), atom(), String.t(), keyword()) :: {:error, Error.t()}
#   def normalize_error(result, default_code \\ :internal_error, default_message \\ "Operation failed", opts \\ [])

#   def normalize_error({:error, %Error{} = error}, _code, _message, _opts), do: {:error, error}
#   def normalize_error({:error, reason}, code, message, opts) do
#     Error.error_result(code, message, Keyword.put(opts, :context, %{reason: reason}))
#   end
#   def normalize_error(:error, code, message, opts) do
#     Error.error_result(code, message, opts)
#   end
#   def normalize_error(other, code, message, opts) do
#     Error.error_result(code, message, Keyword.put(opts, :context, %{unexpected_return: other}))
#   end

#   @doc """
#   Chain operations with early return on error, but more explicit than `with`.
#   """
#   @spec chain([(() -> any())], keyword()) :: any()
#   def chain(operations, opts \\ []) when is_list(operations) do
#     Enum.reduce_while(operations, :ok, fn operation, _acc ->
#       case safe_call(operation, opts) do
#         {:error, _} = error -> {:halt, error}
#         :ok -> {:cont, :ok}
#         {:ok, _} = result -> {:cont, result}
#         result -> {:cont, result}
#       end
#     end)
#   end

#   # Private helpers
#   defp handle_validation_error(error, opts) do
#     context = build_context(error, opts)
#     Error.error_result(
#       :validation_failed,
#       Exception.message(error),
#       Keyword.put(opts, :context, context)
#     )
#   end

#   defp handle_runtime_error(error, opts) do
#     context = build_context(error, opts)
#     Error.error_result(
#       :internal_error,
#       Exception.message(error),
#       Keyword.put(opts, :context, context)
#     )
#   end

#   defp handle_unexpected_error(error, opts) do
#     Logger.error("Unexpected error: #{Exception.message(error)}")
#     context = build_context(error, opts)
#     Error.error_result(
#       :internal_error,
#       "An unexpected error occurred",
#       Keyword.put(opts, :context, Map.put(context, :original_error, Exception.message(error)))
#     )
#   end

#   defp build_context(error, opts) do
#     %{
#       module: Keyword.get(opts, :module),
#       function: Keyword.get(opts, :function),
#       stacktrace: Exception.format_stacktrace(__STACKTRACE__),
#       error_type: error.__struct__
#     }
#   end
# end

# # Approach 2: Result Type Pattern (Railway Oriented Programming)
# defmodule ElixirScope.Foundation.Result do
#   @moduledoc """
#   Result type for railway-oriented programming pattern.
#   Makes success/failure explicit in function signatures.
#   """

#   @type t(success, error) :: {:ok, success} | {:error, error}
#   @type t(success) :: t(success, Error.t())
#   @type t() :: t(any())

#   @doc """
#   Map over the success value, leaving errors unchanged.
#   """
#   @spec map(t(a, e), (a -> b)) :: t(b, e) when a: any(), b: any(), e: any()
#   def map({:ok, value}, mapper) when is_function(mapper, 1) do
#     {:ok, mapper.(value)}
#   end
#   def map({:error, _} = error, _mapper), do: error

#   @doc """
#   Flat map - prevents nested {:ok, {:ok, value}} results.
#   """
#   @spec flat_map(t(a, e), (a -> t(b, e))) :: t(b, e) when a: any(), b: any(), e: any()
#   def flat_map({:ok, value}, mapper) when is_function(mapper, 1) do
#     mapper.(value)
#   end
#   def flat_map({:error, _} = error, _mapper), do: error

#   @doc """
#   Apply a function to the error, leaving success unchanged.
#   """
#   @spec map_error(t(a, e1), (e1 -> e2)) :: t(a, e2) when a: any(), e1: any(), e2: any()
#   def map_error({:ok, _} = success, _mapper), do: success
#   def map_error({:error, error}, mapper) when is_function(mapper, 1) do
#     {:error, mapper.(error)}
#   end

#   @doc """
#   Convert various result formats to standardized Result.t()
#   """
#   @spec from_any(any()) :: t()
#   def from_any(:ok), do: {:ok, nil}
#   def from_any({:ok, _} = result), do: result
#   def from_any({:error, %Error{}} = error), do: error
#   def from_any({:error, reason}), do: {:error, Error.new(:external_error, inspect(reason))}
#   def from_any(:error), do: {:error, Error.new(:operation_failed, "Operation failed")}
#   def from_any(other), do: {:error, Error.new(:unexpected_result, "Unexpected return value", %{value: other})}
# end
