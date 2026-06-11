defmodule RegisteredCompletionScriptsCache do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    IO.inspect(state, label: "STATE")
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:add_script, script}, state) do
    {:noreply, [script | state]}
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_state(script) do
    GenServer.cast(__MODULE__, {:add_script, script})
  end
end
