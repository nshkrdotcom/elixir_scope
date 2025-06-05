alias ElixirScope.Foundation.Infrastructure.RateLimiter.HammerBackend

IO.puts("Testing Hammer API...")

try do
  result = HammerBackend.hit("test_key", 60000, 10, 1)
  IO.inspect(result, label: "HammerBackend.hit result")
rescue
  e ->
    IO.inspect(e, label: "Error")
    IO.inspect(Exception.format(:error, e, __STACKTRACE__), label: "Stacktrace")
end

# Test the 3-arg version
try do
  result3 = HammerBackend.hit("test_key2", 60000, 10)
  IO.inspect(result3, label: "HammerBackend.hit/3 result")
rescue
  e ->
    IO.inspect(e, label: "Error hit/3")
end