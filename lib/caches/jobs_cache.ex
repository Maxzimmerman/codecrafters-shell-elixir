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
  def handle_cast({:pause_job, id}, state) do
    state =
      Enum.map(state, fn
        %BackgroundJob{process_id: ^id} = job -> %{job | status: :obsolete}
        job -> job
      end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_job, id}, _from, state) do
    job =
      Enum.filter(state, fn %BackgroundJob{process_id: process_id} -> process_id == id end)
      |> Enum.at(0)

    {:reply, job, state}
  end

  @impl true
  def handle_call(:get_all_running, _form, state) do
    running =
      Enum.filter(state, fn %BackgroundJob{status: status} -> status == :running end)

    {:reply, running, state}
  end

  @impl true
  def handle_call(:get_all, _form, state) do
    {:reply, state, state}
  end

  def add_job(%BackgroundJob{} = job) do
    GenServer.cast(__MODULE__, {:add_job, job})
  end

  def pause_job(process_id) do
    GenServer.cast(__MODULE__, {:pause_job, process_id})
  end

  def get_all_running, do: GenServer.call(__MODULE__, :get_all_running)
  def get_all, do: GenServer.call(__MODULE__, :get_all)
end
