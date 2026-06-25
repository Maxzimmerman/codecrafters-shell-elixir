defmodule JobsCache do
  use GenServer

  alias DataTypes.BackgroundJob
  alias Commands.Jobs

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
  def handle_call({:pause_job, id}, _from, state) do
    state =
      Enum.map(state, fn
        %BackgroundJob{process_id: ^id} = job -> %{job | status: :obsolete}
        job -> job
      end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:drop_job, id}, state) do
    state = Enum.reject(state, fn %BackgroundJob{process_id: process_id} -> process_id == id end)
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
  def handle_call({:check_job_status, job}, _form, state) do
    job_status =
      Enum.filter(state, fn %BackgroundJob{process_id: process_id} ->
        process_id == job.process_id
      end)
      |> Enum.map(fn %BackgroundJob{status: status} -> status end)
      |> Enum.at(0)

    {:reply, job_status, state}
  end

  @impl true
  def handle_call(:clean_obsolete_jobs, _form, state) do
    obsolets =
      Enum.filter(state, fn %BackgroundJob{status: status} -> status == :obsolete end)

    state = Enum.reject(state, fn %BackgroundJob{status: status} -> status == :obsolete end)

    {:reply, obsolets, state}
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

  def drop_job(process_id) do
    GenServer.cast(__MODULE__, {:drop_job, process_id})
  end

  def get_all_running, do: GenServer.call(__MODULE__, :get_all_running)
  def get_all, do: GenServer.call(__MODULE__, :get_all)
  def get_job(job_id), do: GenServer.call(__MODULE__, {:get_job, job_id})

  def job_done?(%BackgroundJob{} = job) do
    case GenServer.call(__MODULE__, {:check_job_status, job}) do
      :obsolete ->
        true

      :running ->
        false

      _ ->
        nil
    end
  end

  def clean_obsolete_jobs_and_print do
    Jobs.print_jobs(GenServer.call(__MODULE__, :clean_obsolete_jobs))
  end
end
