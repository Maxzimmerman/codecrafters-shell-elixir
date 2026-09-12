defmodule VariableCache do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, {[], 0}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:get_one, variable_key}, _from, state) do
    case Map.get(state, variable_key) do
      :error ->
        {:reply, :not_found, state}

      value ->
        {:reply, value, state}
    end
  end

  @impl true
  def handle_cast({:add_one, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end

  def get_all, do: GenServer.call(__MODULE__, :get_all)
  def get_one(key), do: GenServer.call(__MODULE__, {:get_one, key})
  def add_one(key, value), do: GenServer.cast(__MODULE__, {:add_one, key, value})
end
