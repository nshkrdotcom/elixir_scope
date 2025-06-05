defmodule ElixirScope.Foundation.Infrastructure.CircuitBreakerTest do
  use ExUnit.Case, async: false

  alias ElixirScope.Foundation.Infrastructure.CircuitBreaker
  alias ElixirScope.Foundation.Types.Error

  setup do
    # Clean up any existing fuses before each test
    :fuse.reset(:test_service)
    :fuse.reset(:failing_service)
    :ok
  end

  describe "start_fuse_instance/2" do
    test "creates a new fuse instance with default options" do
      assert :ok = CircuitBreaker.start_fuse_instance(:test_service)
      assert CircuitBreaker.get_status(:test_service) == :ok
    end

    test "creates a fuse instance with custom options" do
      options = [strategy: :standard, tolerance: 3, refresh: 30_000]
      assert :ok = CircuitBreaker.start_fuse_instance(:custom_service, options)
      assert CircuitBreaker.get_status(:custom_service) == :ok
    end

    test "handles already installed fuse gracefully" do
      assert :ok = CircuitBreaker.start_fuse_instance(:duplicate_service)
      assert :ok = CircuitBreaker.start_fuse_instance(:duplicate_service)
    end
  end

  describe "execute/3" do
    setup do
      :ok = CircuitBreaker.start_fuse_instance(:test_service)
      :ok
    end

    test "executes operation successfully when circuit is closed" do
      operation = fn -> {:success, "result"} end

      assert {:ok, {:success, "result"}} = CircuitBreaker.execute(:test_service, operation)
    end

    test "returns error when circuit is blown" do
      # Melt the fuse enough times to blow it (default tolerance is 5)
      for _i <- 1..6 do
        :fuse.melt(:test_service)
      end

      operation = fn -> {:success, "result"} end

      assert {:error, %Error{error_type: :circuit_breaker_blown}} =
               CircuitBreaker.execute(:test_service, operation)
    end

    test "melts fuse when operation fails" do
      failing_operation = fn -> raise "boom" end

      assert {:error, %Error{error_type: :protected_operation_failed}} =
               CircuitBreaker.execute(:test_service, failing_operation)
    end

    test "returns error for non-existent fuse" do
      operation = fn -> "result" end

      assert {:error, %Error{error_type: :circuit_breaker_not_found}} =
               CircuitBreaker.execute(:non_existent_service, operation)
    end

    test "includes metadata in telemetry events" do
      operation = fn -> "result" end
      metadata = %{test_key: "test_value"}

      assert {:ok, "result"} = CircuitBreaker.execute(:test_service, operation, metadata)
    end
  end

  describe "get_status/1" do
    test "returns :ok for healthy circuit" do
      :ok = CircuitBreaker.start_fuse_instance(:healthy_service)
      assert CircuitBreaker.get_status(:healthy_service) == :ok
    end

    test "returns :blown for melted circuit" do
      :ok = CircuitBreaker.start_fuse_instance(:blown_service)
      # Melt the fuse enough times to blow it (default tolerance is 5)
      for _i <- 1..6 do
        :fuse.melt(:blown_service)
      end

      assert CircuitBreaker.get_status(:blown_service) == :blown
    end

    test "returns error for non-existent fuse" do
      assert {:error, %Error{error_type: :circuit_breaker_not_found}} =
               CircuitBreaker.get_status(:non_existent)
    end
  end

  describe "reset/1" do
    setup do
      :ok = CircuitBreaker.start_fuse_instance(:reset_test_service)
      # Melt the fuse enough times to blow it (default tolerance is 5)
      for _i <- 1..6 do
        :fuse.melt(:reset_test_service)
      end

      :ok
    end

    test "resets a blown circuit" do
      assert CircuitBreaker.get_status(:reset_test_service) == :blown
      assert :ok = CircuitBreaker.reset(:reset_test_service)
      assert CircuitBreaker.get_status(:reset_test_service) == :ok
    end

    test "returns error for non-existent fuse" do
      assert {:error, %Error{error_type: :circuit_breaker_not_found}} =
               CircuitBreaker.reset(:non_existent)
    end
  end
end
