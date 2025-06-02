defmodule ElixirScope.Foundation.Types.Event do
  @moduledoc """
  Event data structure for ElixirScope.

  Events represent actions, state changes, and system events that occur
  during ElixirScope operation. This is a pure data structure with no behavior.

  While all fields are optional for maximum flexibility, production events 
  typically should have at least an event_type and timestamp.

  See `@type t` for the complete type specification.

  ## Examples

      iex> event = ElixirScope.Foundation.Types.Event.new([
      ...>   event_type: :config_updated,
      ...>   event_id: 123,
      ...>   timestamp: System.monotonic_time()
      ...> ])
      iex> event.event_type
      :config_updated

      iex> empty_event = ElixirScope.Foundation.Types.Event.new()
      iex> is_nil(empty_event.event_type)
      true
  """

  @typedoc "Unique identifier for an event"
  @type event_id :: pos_integer()

  @typedoc "Correlation identifier for tracking related events"
  @type correlation_id :: String.t()

  defstruct [
    :event_type,
    :event_id,
    :timestamp,
    :wall_time,
    :node,
    :pid,
    :correlation_id,
    :parent_id,
    :data
  ]

  @type t :: %__MODULE__{
          event_type: atom() | nil,
          event_id: event_id() | nil,
          timestamp: integer() | nil,
          wall_time: DateTime.t() | nil,
          node: node() | nil,
          pid: pid() | nil,
          correlation_id: correlation_id() | nil,
          parent_id: event_id() | nil,
          data: term() | nil
        }

  @doc """
  Create a new empty event structure.

  Creates an event with all fields set to nil for backward compatibility.
  Useful for testing and validation scenarios.

  ## Examples

      iex> event = ElixirScope.Foundation.Types.Event.new()
      iex> is_nil(event.event_type)
      true
  """
  @spec new() :: %__MODULE__{
          event_type: nil,
          event_id: nil,
          timestamp: nil,
          wall_time: nil,
          node: nil,
          pid: nil,
          correlation_id: nil,
          parent_id: nil,
          data: nil
        }
  def new do
    %__MODULE__{}
  end

  @doc """
  Create a new event structure.

  Accepts either a single atom for the event_type, or a keyword list with 
  event_type and other fields.

  ## Parameters
  - `event_type_or_fields`: Either an atom (event_type) or keyword list of fields

  ## Examples

      iex> event = ElixirScope.Foundation.Types.Event.new(:process_started)
      iex> event.event_type
      :process_started

      iex> event = ElixirScope.Foundation.Types.Event.new([
      ...>   event_type: :process_started,
      ...>   event_id: 456,
      ...>   timestamp: System.monotonic_time(),
      ...>   pid: self()
      ...> ])
      iex> event.event_type
      :process_started
  """
  @spec new(atom()) :: t()
  @spec new(keyword()) :: t()
  def new(event_type) when is_atom(event_type) do
    %__MODULE__{event_type: event_type}
  end

  def new(fields) when is_list(fields) do
    struct(__MODULE__, fields)
  end
end
