defmodule JobsCache do
  use GenServer

  alias DataTypes.BackgroundJob

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:add_job, job}, state) do
    {:noreply, [job | state]}
  end

  @impl true
  def handle_call({:get_job, id}, _from, state) do
    job =
      Enum.filter(state, fn %BackgroundJob{process_id: process_id} -> process_id == id end)
      |> Enum.at(0)

    {:reply, job, state}
  end
end
