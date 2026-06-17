defmodule RegisteredCompletionScriptsCache do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:add_script, name, path}, state) do
    {:noreply, Map.put(state, name, path)}
  end

  @impl true
  def handle_cast({:delete_script, name}, state) do
    {:noreply, Map.delete(state, name)}
  end

  @impl true
  def handle_call({:get_script, name}, _from, state) do
    {:reply, Map.get(state, name), state}
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_state(name, path) do
    GenServer.cast(__MODULE__, {:add_script, name, path})
  end

  def get_with_name(name) do
    GenServer.call(__MODULE__, {:get_script, name})
  end

  def delete_with_name(name) do
    GenServer.cast(__MODULE__, {:delete_script, name})
  end
end
