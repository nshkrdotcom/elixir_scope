defmodule ElixirScope.Foundation.Types.ErrorTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Foundation.Types.Error

  describe "new/0" do
    test "creates error with defaults" do
      error = Error.new()

      assert %DateTime{} = error.timestamp
      assert error.context == %{}
      assert error.recovery_actions == []
    end
  end

  describe "new/1" do
    test "creates error with provided fields and merges defaults" do
      fields = [
        error_type: :validation_failed,
        message: "Test error",
        severity: :high,
        context: %{field: "test"}
      ]

      error = Error.new(fields)

      assert error.error_type == :validation_failed
      assert error.message == "Test error"
      assert error.severity == :high
      assert error.context == %{field: "test"}
      assert %DateTime{} = error.timestamp  # Default added
      assert error.recovery_actions == []   # Default added
    end
  end
end
