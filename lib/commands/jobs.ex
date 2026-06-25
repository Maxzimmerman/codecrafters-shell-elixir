defmodule Commands.Jobs do
  @behaviour Commands.Command

  @impl true
  def execute(_args) do
    jobs = JobsCache.get_all_running()

    case length(jobs) do
      1 ->
        [job] = jobs

        command =
          String.split(job.command_str, "/")
          |> Enum.at(-1)

        IO.puts("[#{job.job_number}]+  Running                 #{command}")

      0 ->
        :ok

      length when length > 1 ->
        IO.inspect(jobs)
    end
  end
end
