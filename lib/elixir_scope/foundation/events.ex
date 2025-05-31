defmodule ElixirScope.Foundation.Events do
  @moduledoc """
  Core event system for ElixirScope.

  Provides structured event creation, serialization, and basic event management.
  This is the foundation for all event-driven communication within ElixirScope.
  """

  require Logger

  alias ElixirScope.Foundation.{Types, Utils, Error, ErrorContext}

  @type event_id :: Types.event_id()
  @type timestamp :: Types.timestamp()
  @type correlation_id :: Types.correlation_id()

  # Base event structure
  defstruct [
    :event_id,
    :event_type,
    :timestamp,
    :wall_time,
    :node,
    :pid,
    :correlation_id,
    :parent_id,
    :data
  ]

  @type t :: %__MODULE__{
          event_id: event_id(),
          event_type: atom(),
          timestamp: timestamp(),
          wall_time: DateTime.t(),
          node: node(),
          pid: pid(),
          correlation_id: correlation_id() | nil,
          parent_id: event_id() | nil,
          data: term()
        }

  ## System Management

  @spec initialize() :: :ok
  def initialize do
    Logger.debug("ElixirScope.Foundation.Events initialized")
    :ok
  end

  @spec status() :: :ok
  def status, do: :ok

  ## Event Creation

  @spec new_event(atom(), term(), keyword()) :: t() | {:error, Error.t()}
  def new_event(event_type, data, opts \\ []) do
    context =
      ErrorContext.new(__MODULE__, :new_event, metadata: %{event_type: event_type, opts: opts})

    ErrorContext.with_context(context, fn ->
      event = %__MODULE__{
        event_id: Utils.generate_id(),
        event_type: event_type,
        timestamp: Utils.monotonic_timestamp(),
        wall_time: DateTime.utc_now(),
        node: Node.self(),
        pid: self(),
        correlation_id: Keyword.get(opts, :correlation_id),
        parent_id: Keyword.get(opts, :parent_id),
        data: data
      }

      case validate_event(event) do
        :ok -> event
        {:error, _} = error -> error
      end
    end)
  end

  @spec function_entry(module(), atom(), arity(), [term()], keyword()) :: t() | {:error, Error.t()}
  def function_entry(module, function, arity, args, opts \\ []) do
    data = %{
      call_id: Utils.generate_id(),
      module: module,
      function: function,
      arity: arity,
      args: Utils.truncate_if_large(args),
      caller_module: Keyword.get(opts, :caller_module),
      caller_function: Keyword.get(opts, :caller_function),
      caller_line: Keyword.get(opts, :caller_line)
    }

    new_event(:function_entry, data, opts)
  end

  @spec function_exit(module(), atom(), arity(), event_id(), term(), non_neg_integer(), atom()) ::
          t() | {:error, Error.t()}
  def function_exit(module, function, arity, call_id, result, duration_ns, exit_reason) do
    data = %{
      call_id: call_id,
      module: module,
      function: function,
      arity: arity,
      result: Utils.truncate_if_large(result),
      duration_ns: duration_ns,
      exit_reason: exit_reason
    }

    new_event(:function_exit, data)
  end

  @spec state_change(pid(), atom(), term(), term(), keyword()) :: t() | {:error, Error.t()}
  def state_change(server_pid, callback, old_state, new_state, opts \\ []) do
    data = %{
      server_pid: server_pid,
      callback: callback,
      old_state: Utils.truncate_if_large(old_state),
      new_state: Utils.truncate_if_large(new_state),
      state_diff: compute_state_diff(old_state, new_state),
      trigger_message: Keyword.get(opts, :trigger_message),
      trigger_call_id: Keyword.get(opts, :trigger_call_id)
    }

    new_event(:state_change, data)
  end

  ## Event Serialization

  @spec serialize(t()) :: binary() | {:error, Error.t()}
  def serialize(%__MODULE__{} = event) do
    context = ErrorContext.new(__MODULE__, :serialize)

    ErrorContext.with_context(context, fn ->
      :erlang.term_to_binary(event, [:compressed])
    end)
  end

  @spec deserialize(binary()) :: t() | {:error, Error.t()}
  def deserialize(binary) when is_binary(binary) do
    context = ErrorContext.new(__MODULE__, :deserialize)

    ErrorContext.with_context(context, fn ->
      event = :erlang.binary_to_term(binary)

      case validate_event(event) do
        :ok -> event
        {:error, _} = error -> error
      end
    end)
  end

  @spec serialized_size(t()) :: non_neg_integer()
  def serialized_size(%__MODULE__{} = event) do
    case serialize(event) do
      {:error, _} -> 0
      binary when is_binary(binary) -> byte_size(binary)
    end
  end

  ## Private Validation

  @spec validate_event(t()) :: :ok | {:error, Error.t()}
  defp validate_event(%__MODULE__{} = event) do
    cond do
      is_nil(event.event_id) ->
        Error.error_result(:validation_failed, "Event ID cannot be nil")

      not is_atom(event.event_type) ->
        Error.error_result(:type_mismatch, "Event type must be an atom")

      not is_integer(event.timestamp) ->
        Error.error_result(:type_mismatch, "Timestamp must be an integer")

      true ->
        :ok
    end
  end

  defp validate_event(_) do
    Error.error_result(:type_mismatch, "Expected Events struct")
  end

  ## Private Helper Functions

  @spec compute_state_diff(term(), term()) :: :no_change | :changed
  defp compute_state_diff(old_state, new_state) do
    if old_state == new_state do
      :no_change
    else
      :changed
    end
  end
end

# ## Event Creation

# @spec new_event(atom(), term(), keyword()) :: t()
# def new_event(event_type, data, opts \\ []) do
#   %__MODULE__{
#     event_id: Utils.generate_id(),
#     event_type: event_type,
#     timestamp: Utils.monotonic_timestamp(),
#     wall_time: DateTime.utc_now(),
#     node: Node.self(),
#     pid: self(),
#     correlation_id: Keyword.get(opts, :correlation_id),
#     parent_id: Keyword.get(opts, :parent_id),
#     data: data
#   }
# end

# @spec function_entry(module(), atom(), arity(), [term()], keyword()) :: t()
# def function_entry(module, function, arity, args, opts \\ []) do
#   data = %{
#     call_id: Utils.generate_id(),
#     module: module,
#     function: function,
#     arity: arity,
#     args: Utils.truncate_if_large(args),
#     caller_module: Keyword.get(opts, :caller_module),
#     caller_function: Keyword.get(opts, :caller_function),
#     caller_line: Keyword.get(opts, :caller_line)
#   }

#   new_event(:function_entry, data, opts)
# end

# @spec function_exit(module(), atom(), arity(), event_id(), term(), non_neg_integer(), atom()) :: t()
# def function_exit(module, function, arity, call_id, result, duration_ns, exit_reason) do
#   data = %{
#     call_id: call_id,
#     module: module,
#     function: function,
#     arity: arity,
#     result: Utils.truncate_if_large(result),
#     duration_ns: duration_ns,
#     exit_reason: exit_reason
#   }

#   new_event(:function_exit, data)
# end

# @spec state_change(pid(), atom(), term(), term(), keyword()) :: t()
# def state_change(server_pid, callback, old_state, new_state, opts \\ []) do
#   data = %{
#     server_pid: server_pid,
#     callback: callback,
#     old_state: Utils.truncate_if_large(old_state),
#     new_state: Utils.truncate_if_large(new_state),
#     state_diff: compute_state_diff(old_state, new_state),
#     trigger_message: Keyword.get(opts, :trigger_message),
#     trigger_call_id: Keyword.get(opts, :trigger_call_id)
#   }

#   new_event(:state_change, data)
# end

# ## Event Processing

# @spec serialize(t()) :: binary()
# def serialize(%__MODULE__{} = event) do
#   :erlang.term_to_binary(event, [:compressed])
# end

# @spec deserialize(binary()) :: t()
# def deserialize(binary) when is_binary(binary) do
#   :erlang.binary_to_term(binary)
# end

# @spec serialized_size(t()) :: non_neg_integer()
# def serialized_size(%__MODULE__{} = event) do
#   event |> serialize() |> byte_size()
# end

## Private Functions

# defp compute_state_diff(old_state, new_state) do
#   if old_state == new_state do
#     :no_change
#   else
#     :changed
#   end
# end
# end
