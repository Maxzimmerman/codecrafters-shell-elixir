defmodule HistoryCache do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, {[], 0}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:get_all, _from, {history, _appended} = state) do
    {:reply, history, state}
  end

  @impl true
  def handle_call(:take_pending_append, _from, {history, appended}) do
    total = length(history)
    pending_count = total - appended

    pending =
      history
      |> Enum.take(pending_count)
      |> Enum.reverse()

    {:reply, pending, {history, total}}
  end

  @impl true
  def handle_cast({:add_one, command}, {history, appended}) do
    {:noreply, {[command | history], appended}}
  end

  def get_all, do: GenServer.call(__MODULE__, :get_all)
  def add_one(command), do: GenServer.cast(__MODULE__, {:add_one, command})
  def take_pending_append, do: GenServer.call(__MODULE__, :take_pending_append)
end
