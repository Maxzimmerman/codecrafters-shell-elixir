defmodule Commands.Jobs do
  @behaviour Commands.Command

  alias DataTypes.BackgroundJob

  @impl true
  def execute(args) do
    jobs =
      JobsCache.get_all()

    if length(jobs) == 0 do
      :ok
    else
      [job | _] = jobs

      command =
        String.split(job.command_str, "/")
        |> Enum.at(-1)

      case Enum.find_index(jobs, &(&1.id == job.id)) do
        nil ->
          :not_found

        idx ->
          case length(jobs) - 1 - idx do
            0 -> IO.puts("[#{job.job_number}]+  Running                 #{command}")
            1 -> IO.puts("[#{job.job_number}]-  Running                 #{command}")
            _ -> IO.puts("[#{job.job_number}]   Running                 #{command}")
          end
      end
    end
  end
end
