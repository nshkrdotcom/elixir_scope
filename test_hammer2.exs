alias ElixirScope.Foundation.Infrastructure.RateLimiter.HammerBackend

IO.puts("Testing Hammer API with exact types from code...")

# Test with exactly the same call pattern as in the rate limiter
entity_id = "test_user"
operation = :api_call
limit = 100
time_window_ms = 60_000

key = "elixir_scope:#{entity_id}:#{operation}"

IO.inspect([key, time_window_ms, limit, 1], label: "Arguments")

try do
  result = HammerBackend.hit(key, time_window_ms, limit, 1)
  IO.inspect(result, label: "Result")
  
  case result do
    {:allow, count} -> 
      IO.puts("Allow case matched with count: #{count}")
    {:deny, limit} -> 
      IO.puts("Deny case matched with limit: #{limit}")
    other ->
      IO.inspect(other, label: "Other result")
  end
rescue
  e ->
    IO.inspect(e, label: "Error")
    IO.inspect(Exception.format(:error, e, __STACKTRACE__), label: "Stacktrace")
end