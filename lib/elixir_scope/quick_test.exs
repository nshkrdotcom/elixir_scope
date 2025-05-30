# Quick test to verify basic module loading
modules_to_test = [
  ElixirScope.Foundation,
  ElixirScope.AST,
  ElixirScope.Graph,
  ElixirScope.CPG,
  ElixirScope.Analysis,
  ElixirScope.Query,
  ElixirScope.Capture,
  ElixirScope.Intelligence,
  ElixirScope.Debugger
]

IO.puts("🧪 Testing module definitions...")

Enum.each(modules_to_test, fn module ->
  try do
    Code.ensure_loaded(module)
    IO.puts("✅ #{module} - Module defined")
  rescue
    e ->
      IO.puts("❌ #{module} - #{Exception.message(e)}")
  end
end)

IO.puts("🎯 Basic module test complete")
