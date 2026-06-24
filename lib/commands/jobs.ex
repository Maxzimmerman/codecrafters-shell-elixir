defmodule Commands.Jobs do
  @behaviour Commands.Command

  @impl true
  def execute(_args) do
    jobs = JobsCache.get_all_running()
    IO.inspect(jobs)

    case length(jobs) do
      1 ->
        [job] = jobs
        IO.inspect(job)
    end
  end
end
