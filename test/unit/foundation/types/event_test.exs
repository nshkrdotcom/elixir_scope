defmodule ElixirScope.Foundation.Types.EventTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Foundation.Types.Event

  describe "new/0" do
    test "creates empty event structure" do
      event = Event.new()

      assert %Event{} = event
      assert is_nil(event.event_id)
      assert is_nil(event.event_type)
      assert is_nil(event.timestamp)
    end
  end

  describe "new/1" do
    test "creates event with provided fields" do
      fields = [
        event_id: 123,
        event_type: :test,
        timestamp: 456_789,
        data: %{key: "value"}
      ]

      event = Event.new(fields)

      assert event.event_id == 123
      assert event.event_type == :test
      assert event.timestamp == 456_789
      assert event.data == %{key: "value"}
    end
  end
end
