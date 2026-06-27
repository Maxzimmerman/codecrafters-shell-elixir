defmodule HistoryCache do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:add_one, command}, state) do
    {:noreply, [command | state]}
  end

  def get_all, do: GenServer.call(__MODULE__, :get_all)
  def add_one(command), do: GenServer.cast(__MODULE__, {:add_one, command})
end
