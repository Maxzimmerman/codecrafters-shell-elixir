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
  def handle_cast(:get_state, state) do
    IO.inspect(state, label: "STATE")
    {:noreply, state}
  end

  def get_state do
    GenServer.call(self(), :get_state)
  end
end
