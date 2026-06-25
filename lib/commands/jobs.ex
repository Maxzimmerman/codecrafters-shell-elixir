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

      IO.inspect(args)
      IO.puts("[#{job.job_number}]+  Running                 #{command}")
    end
  end
end
