# ORIG_FILE
defmodule FixtureApp.SimpleModule do
  @moduledoc """
  A simple module for testing basic functionality.
  """
  
  def hello(name) when is_binary(name) do
    "Hello, #{name}!"
  end
  
  def hello(_), do: "Hello, World!"
  
  def add(a, b) when is_number(a) and is_number(b) do
    a + b
  end
  
  defp internal_function do
    :internal
  end
end
