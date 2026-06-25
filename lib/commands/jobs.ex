defmodule Commands.Jobs do
  @behaviour Commands.Command

  @impl true
  def execute(_args) do
    jobs = JobsCache.get_all() |> Enum.sort_by(& &1.job_number)
    total = length(jobs)

    jobs
    |> Enum.with_index()
    |> Enum.each(fn {job, idx} ->
      marker =
        case total - 1 - idx do
          0 -> "+"
          1 -> "-"
          _ -> " "
        end

      command =
        String.split(job.command_str, "/")
        |> Enum.at(-1)

      IO.puts("[#{job.job_number}]#{marker}  Running                 #{command}")
    end)
  end
end
