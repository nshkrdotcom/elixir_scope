# ORIG_FILE
defmodule FixtureApp.Worker do
  use GenServer

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def update_state(new_state) do
    GenServer.cast(__MODULE__, {:update_state, new_state})
  end

  # Server callbacks
  def init(opts) do
    initial_state = Keyword.get(opts, :initial_state, %{})
    {:ok, initial_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:update_state, new_state}, _state) do
    {:noreply, new_state}
  end
end
