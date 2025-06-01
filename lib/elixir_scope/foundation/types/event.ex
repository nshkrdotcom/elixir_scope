defmodule ElixirScope.Foundation.Types.Event do
  @moduledoc """
  Event data structure for ElixirScope.

  Events represent actions, state changes, and system events that occur
  during ElixirScope operation. This is a pure data structure with no behavior.

  While all fields are technically optional for flexibility in testing and
  validation scenarios, production events typically require an ID, type, and timestamp.

  See `@type t` for the complete type specification.

  ## Examples

      iex> event = ElixirScope.Foundation.Types.Event.new([
      ...>   event_id: 123,
      ...>   event_type: :config_updated,
      ...>   timestamp: System.monotonic_time()
      ...> ])
      iex> event.event_type
      :config_updated

      iex> empty_event = ElixirScope.Foundation.Types.Event.new()
      iex> empty_event.event_id
      nil
  """

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

  @typedoc "Unique identifier for an event"
  @type event_id :: pos_integer()

  @typedoc "Correlation identifier for tracking related events"
  @type correlation_id :: String.t()

  @type t :: %__MODULE__{
          event_id: event_id() | nil,
          event_type: atom() | nil,
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

  Useful for testing and validation scenarios.

  ## Examples

      iex> event = ElixirScope.Foundation.Types.Event.new()
      iex> event.event_id
      nil
  """
  @spec new() :: %__MODULE__{
          event_id: nil,
          event_type: nil,
          timestamp: nil,
          wall_time: nil,
          node: nil,
          pid: nil,
          correlation_id: nil,
          parent_id: nil,
          data: nil
        }
  def new, do: %__MODULE__{}

  @doc """
  Create a new event structure with specified fields.

  ## Parameters
  - `fields`: Keyword list of event fields to set

  ## Examples

      iex> event = ElixirScope.Foundation.Types.Event.new([
      ...>   event_id: 456,
      ...>   event_type: :process_started,
      ...>   timestamp: System.monotonic_time(),
      ...>   pid: self()
      ...> ])
      iex> event.event_type
      :process_started
  """
  @spec new(keyword()) :: t()
  def new(fields) do
    struct(__MODULE__, fields)
  end
end
