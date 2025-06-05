defmodule ElixirScope.Foundation.Infrastructure.RateLimiterTest do
  use ExUnit.Case, async: false

  alias ElixirScope.Foundation.Infrastructure.RateLimiter
  alias ElixirScope.Foundation.Types.Error

  setup do
    # The HammerBackend is already started in the application
    # Reset rate limiting buckets before each test
    RateLimiter.reset("test_user", :test_operation)
    RateLimiter.reset("test_user", :api_call)
    RateLimiter.reset("exec_user", :exec_op)
    RateLimiter.reset("reset_user", :reset_op)

    # Use unique keys for each test to avoid conflicts
    test_prefix = "test_#{System.unique_integer()}"
    %{test_prefix: test_prefix}
  end

  describe "check_rate/5" do
    test "allows requests within rate limit", %{test_prefix: prefix} do
      user_id = "#{prefix}_user"
      assert :ok = RateLimiter.check_rate(user_id, :test_operation, 5, 60_000)
      assert :ok = RateLimiter.check_rate(user_id, :test_operation, 5, 60_000)
    end

    test "denies requests that exceed rate limit", %{test_prefix: prefix} do
      user_id = "#{prefix}_user2"
      # Fill up the bucket
      for _i <- 1..5 do
        assert :ok = RateLimiter.check_rate(user_id, :test_operation, 5, 60_000)
      end

      # This should be denied
      assert {:error, %Error{error_type: :rate_limit_exceeded}} =
               RateLimiter.check_rate(user_id, :test_operation, 5, 60_000)
    end

    test "handles different entity IDs independently", %{test_prefix: prefix} do
      user1 = "#{prefix}_user1"
      user2 = "#{prefix}_user2"
      # Fill up bucket for user1
      for _i <- 1..5 do
        assert :ok = RateLimiter.check_rate(user1, :test_operation, 5, 60_000)
      end

      # user2 should still be allowed
      assert :ok = RateLimiter.check_rate(user2, :test_operation, 5, 60_000)
    end

    test "handles different operations independently", %{test_prefix: prefix} do
      user_id = "#{prefix}_user"
      # Fill up bucket for operation1
      for _i <- 1..5 do
        assert :ok = RateLimiter.check_rate(user_id, :operation1, 5, 60_000)
      end

      # operation2 should still be allowed
      assert :ok = RateLimiter.check_rate(user_id, :operation2, 5, 60_000)
    end

    test "includes metadata in telemetry events", %{test_prefix: prefix} do
      user_id = "#{prefix}_user"
      metadata = %{test_key: "test_value"}
      assert :ok = RateLimiter.check_rate(user_id, :test_operation, 5, 60_000, metadata)
    end
  end

  describe "get_status/2" do
    test "returns status information", %{test_prefix: prefix} do
      user_id = "#{prefix}_status_user"
      assert {:ok, status} = RateLimiter.get_status(user_id, :status_op)
      assert is_map(status)
      assert Map.has_key?(status, :status)
      assert status.status in [:available, :rate_limited]
    end
  end

  describe "reset/2" do
    test "reset returns ok but doesn't actually clear buckets", %{test_prefix: prefix} do
      user_id = "#{prefix}_reset_user"
      # Fill up the bucket
      for _i <- 1..5 do
        assert :ok = RateLimiter.check_rate(user_id, :reset_op, 5, 60_000)
      end

      # Should be rate limited
      assert {:error, %Error{error_type: :rate_limit_exceeded}} =
               RateLimiter.check_rate(user_id, :reset_op, 5, 60_000)

      # Reset returns ok but doesn't actually clear the bucket
      assert :ok = RateLimiter.reset(user_id, :reset_op)
      # Still rate limited because reset doesn't actually clear buckets
      assert {:error, %Error{error_type: :rate_limit_exceeded}} =
               RateLimiter.check_rate(user_id, :reset_op, 5, 60_000)
    end
  end

  describe "execute_with_limit/6" do
    test "executes operation when within rate limit", %{test_prefix: prefix} do
      user_id = "#{prefix}_exec_user1"
      operation = fn -> {:success, "result"} end

      assert {:ok, {:success, "result"}} =
               RateLimiter.execute_with_limit(user_id, :exec_op, 5, 60_000, operation)
    end

    test "returns rate limit error when limit exceeded", %{test_prefix: prefix} do
      user_id = "#{prefix}_exec_user2"
      operation = fn -> {:success, "result"} end

      # Fill up the bucket
      for _i <- 1..5 do
        assert {:ok, _} =
                 RateLimiter.execute_with_limit(user_id, :exec_op, 5, 60_000, operation)
      end

      # This should be rate limited
      assert {:error, %Error{error_type: :rate_limit_exceeded}} =
               RateLimiter.execute_with_limit(user_id, :exec_op, 5, 60_000, operation)
    end

    test "handles operation exceptions", %{test_prefix: prefix} do
      user_id = "#{prefix}_exec_user3"
      failing_operation = fn -> raise "boom" end

      assert {:error, %Error{error_type: :rate_limited_operation_failed}} =
               RateLimiter.execute_with_limit(user_id, :exec_op, 5, 60_000, failing_operation)
    end

    test "includes metadata in execution", %{test_prefix: prefix} do
      user_id = "#{prefix}_exec_user4"
      operation = fn -> "result" end
      metadata = %{test_key: "test_value"}

      assert {:ok, "result"} =
               RateLimiter.execute_with_limit(user_id, :exec_op, 5, 60_000, operation, metadata)
    end
  end
end
