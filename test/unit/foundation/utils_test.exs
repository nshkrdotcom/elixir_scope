defmodule ElixirScope.Foundation.UtilsTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Foundation.Utils

  describe "ID generation" do
    test "generates unique integer IDs" do
      id1 = Utils.generate_id()
      id2 = Utils.generate_id()

      assert is_integer(id1)
      assert is_integer(id2)
      assert id1 != id2
    end

    test "generates many unique IDs" do
      count = 1000
      ids = for _i <- 1..count, do: Utils.generate_id()

      unique_ids = Enum.uniq(ids)
      assert length(unique_ids) == count
    end

    test "generates UUID format correlation IDs" do
      corr_id = Utils.generate_correlation_id()

      assert is_binary(corr_id)
      assert String.length(corr_id) == 36
      assert Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, corr_id)
    end

    test "extracts timestamp from ID" do
      id = Utils.generate_id()
      extracted_timestamp = Utils.id_to_timestamp(id)

      assert is_integer(extracted_timestamp)
    end
  end

  describe "time utilities" do
    test "generates monotonic timestamps" do
      timestamp1 = Utils.monotonic_timestamp()
      timestamp2 = Utils.monotonic_timestamp()

      assert is_integer(timestamp1)
      assert is_integer(timestamp2)
      assert timestamp2 >= timestamp1
    end

    test "generates wall timestamps" do
      timestamp = Utils.wall_timestamp()

      assert is_integer(timestamp)
      # Should be a reasonable timestamp (after 2020)
      assert timestamp > 1_577_836_800_000_000_000  # 2020-01-01 in nanoseconds
    end

    test "formats timestamps correctly" do
      timestamp_ns = 1_609_459_200_000_000_000  # 2021-01-01 00:00:00 UTC
      formatted = Utils.format_timestamp(timestamp_ns)

      assert is_binary(formatted)
      assert String.contains?(formatted, "2021")
    end
  end

  describe "measurement utilities" do
    test "measures execution time" do
      sleep_time = 10  # milliseconds

      {result, duration} = Utils.measure(fn ->
        :timer.sleep(sleep_time)
        :test_result
      end)

      assert result == :test_result
      assert is_integer(duration)
      assert duration >= sleep_time * 1_000_000  # Convert to nanoseconds
    end

    test "measures memory usage" do
      {result, {mem_before, mem_after, diff}} = Utils.measure_memory(fn ->
        Enum.to_list(1..1000)
      end)

      assert is_list(result)
      assert length(result) == 1000
      assert is_integer(mem_before)
      assert is_integer(mem_after)
      assert is_integer(diff)
    end
  end

  describe "data utilities" do
    test "safely inspects terms" do
      data = %{key: "value", nested: %{list: [1, 2, 3]}}
      result = Utils.safe_inspect(data)

      assert is_binary(result)
      assert String.contains?(result, "key")
      assert String.contains?(result, "value")
    end

    test "truncates large terms" do
      small_term = "small"
      large_term = String.duplicate("x", 2000)

      small_result = Utils.truncate_if_large(small_term, 1000)
      large_result = Utils.truncate_if_large(large_term, 1000)

      assert small_result == small_term
      assert match?({:truncated, _, _}, large_result)
    end

    test "estimates term size" do
      small_term = :atom
      large_term = String.duplicate("x", 1000)

      small_size = Utils.term_size(small_term)
      large_size = Utils.term_size(large_term)

      assert is_integer(small_size)
      assert is_integer(large_size)
      assert large_size > small_size
    end
  end

  describe "formatting utilities" do
    test "formats bytes correctly" do
      assert Utils.format_bytes(0) == "0 B"
      assert Utils.format_bytes(512) == "512 B"
      assert Utils.format_bytes(1024) == "1.0 KB"
      assert Utils.format_bytes(1_048_576) == "1.0 MB"
      assert Utils.format_bytes(1_073_741_824) == "1.0 GB"
    end

    test "formats durations correctly" do
      assert Utils.format_duration(0) == "0 ns"
      assert Utils.format_duration(500) == "500 ns"
      assert Utils.format_duration(1_500) == "1.5 μs"
      assert Utils.format_duration(1_500_000) == "1.5 ms"
      assert Utils.format_duration(1_500_000_000) == "1.5 s"
    end
  end

  describe "validation utilities" do
    test "validates positive integers" do
      assert Utils.valid_positive_integer?(1) == true
      assert Utils.valid_positive_integer?(100) == true
      assert Utils.valid_positive_integer?(0) == false
      assert Utils.valid_positive_integer?(-1) == false
      assert Utils.valid_positive_integer?(1.5) == false
      assert Utils.valid_positive_integer?("1") == false
    end

    test "validates percentages" do
      assert Utils.valid_percentage?(0.0) == true
      assert Utils.valid_percentage?(0.5) == true
      assert Utils.valid_percentage?(1.0) == true
      assert Utils.valid_percentage?(-0.1) == false
      assert Utils.valid_percentage?(1.1) == false
      assert Utils.valid_percentage?("0.5") == false
    end

    test "validates PIDs" do
      assert Utils.valid_pid?(self()) == true

      # Create and kill a process
      dead_pid = spawn(fn -> nil end)
      Process.sleep(10)
      assert Utils.valid_pid?(dead_pid) == false

      assert Utils.valid_pid?("not_a_pid") == false
    end
  end

  describe "system stats" do
    test "gets process stats for current process" do
      stats = Utils.process_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :memory)
      assert Map.has_key?(stats, :reductions)
      assert Map.has_key?(stats, :message_queue_len)
      assert Map.has_key?(stats, :timestamp)

      assert is_integer(stats.memory)
      assert stats.memory > 0
    end

    test "gets system stats" do
      stats = Utils.system_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :timestamp)
      assert Map.has_key?(stats, :process_count)
      assert Map.has_key?(stats, :total_memory)
      assert Map.has_key?(stats, :scheduler_count)

      assert is_integer(stats.process_count)
      assert stats.process_count > 0
    end
  end
end
