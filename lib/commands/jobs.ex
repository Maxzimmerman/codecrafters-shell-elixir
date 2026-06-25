defmodule Commands.Jobs do
  @behaviour Commands.Command

  @impl true
  def execute(_args) do
    jobs = JobsCache.get_all() |> Enum.sort_by(& &1.job_number)

    print_jobs(jobs)
  end

  def print_jobs(jobs) do
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

      case JobsCache.job_done?(job) do
        false ->
          IO.puts("[#{job.job_number}]#{marker}  Running                 #{job.command_str}")

        true ->
          JobsCache.drop_job(job.process_id)
          done_command = String.replace_suffix(job.command_str, " &", "")
          IO.puts("[#{job.job_number}]#{marker}  Done                 #{done_command}")

        nil ->
          :ok
      end
    end)
  end

  def print_done(jobs) do
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

      done_command = String.replace_suffix(job.command_str, " &", "")
      IO.puts("[#{job.job_number}]#{marker}  Done                 #{done_command}")
    end)
  end
end
