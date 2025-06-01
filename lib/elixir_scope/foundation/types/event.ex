defmodule ElixirScope.Foundation.Types.Event do
  @moduledoc """
  Event data structure for ElixirScope.

  Events represent actions, state changes, and system events that occur
  during ElixirScope operation. This is a pure data structure with no behavior.
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

  @type event_id :: pos_integer()
  @type correlation_id :: String.t()

  @type t :: %__MODULE__{
          event_id: event_id(),
          event_type: atom(),
          timestamp: integer(),
          wall_time: DateTime.t(),
          node: node(),
          pid: pid(),
          correlation_id: correlation_id() | nil,
          parent_id: event_id() | nil,
          data: term()
        }

  @doc """
  Create a new empty event structure.
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
  Create a new event with the given fields.
  """
  @spec new(keyword()) :: t()
  def new(fields) do
    struct(__MODULE__, fields)
  end
end
