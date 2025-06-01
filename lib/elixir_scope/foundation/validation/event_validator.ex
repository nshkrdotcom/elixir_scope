defmodule ElixirScope.Foundation.Validation.EventValidator do
  @moduledoc """
  Pure validation functions for event structures.

  Contains only validation logic - no side effects, no business logic.
  All functions are pure and easily testable.
  """

  alias ElixirScope.Foundation.Types.{Event, Error}

  @doc """
  Validate an event structure.
  """
  @spec validate(Event.t()) :: :ok | {:error, Error.t()}
  def validate(%Event{} = event) do
    with :ok <- validate_required_fields(event),
         :ok <- validate_field_types(event),
         :ok <- validate_data_size(event) do
      :ok
    end
  end

  @doc """
  Validate that an event has all required fields.
  """
  @spec validate_required_fields(Event.t()) :: :ok | {:error, Error.t()}
  def validate_required_fields(%Event{} = event) do
    cond do
      is_nil(event.event_id) ->
        create_error(:validation_failed, "Event ID cannot be nil")

      not is_atom(event.event_type) ->
        create_error(:type_mismatch, "Event type must be an atom")

      not is_integer(event.timestamp) ->
        create_error(:type_mismatch, "Timestamp must be an integer")

      not is_struct(event.wall_time, DateTime) ->
        create_error(:type_mismatch, "Wall time must be a DateTime")

      true ->
        :ok
    end
  end

  @doc """
  Validate event field types.
  """
  @spec validate_field_types(Event.t()) :: :ok | {:error, Error.t()}
  def validate_field_types(%Event{} = event) do
    cond do
      not is_integer(event.event_id) or event.event_id <= 0 ->
        create_error(:type_mismatch, "Event ID must be a positive integer")

      not is_atom(event.node) ->
        create_error(:type_mismatch, "Node must be an atom")

      not is_pid(event.pid) ->
        create_error(:type_mismatch, "PID must be a process identifier")

      event.correlation_id && not is_binary(event.correlation_id) ->
        create_error(:type_mismatch, "Correlation ID must be a string")

      event.parent_id && (not is_integer(event.parent_id) or event.parent_id <= 0) ->
        create_error(:type_mismatch, "Parent ID must be a positive integer")

      true ->
        :ok
    end
  end

  @doc """
  Validate event data size (to prevent memory issues).
  """
  @spec validate_data_size(Event.t()) :: :ok | {:error, Error.t()}
  def validate_data_size(%Event{data: data}) do
    # Check if data is too large (prevent memory issues)
    size = estimate_size(data)

    if size > 1_000_000 do
      create_error(
        :data_too_large,
        "Event data too large",
        %{size: size, max_size: 1_000_000}
      )
    else
      :ok
    end
  end

  @doc """
  Validate event type is allowed.
  """
  @spec validate_event_type(atom()) :: :ok | {:error, Error.t()}
  def validate_event_type(event_type) when is_atom(event_type) do
    # Define allowed event types
    allowed_types = [
      :function_entry,
      :function_exit,
      :state_change,
      :message_send,
      :message_receive,
      :spawn,
      :exit,
      :link,
      :unlink,
      :monitor,
      :demonitor,
      :system_event,
      :custom_event
    ]

    if event_type in allowed_types do
      :ok
    else
      create_error(
        :invalid_event_type,
        "Invalid event type",
        %{event_type: event_type, allowed_types: allowed_types}
      )
    end
  end

  def validate_event_type(_) do
    create_error(:type_mismatch, "Event type must be an atom")
  end

  ## Private Functions

  defp estimate_size(data) do
    try do
      :erlang.external_size(data)
    rescue
      _ -> 0
    end
  end

  defp create_error(error_type, message, context \\ %{}) do
    error =
      Error.new(
        error_type: error_type,
        message: message,
        context: context,
        category: :data,
        subcategory: :validation,
        severity: :medium
      )

    {:error, error}
  end
end
