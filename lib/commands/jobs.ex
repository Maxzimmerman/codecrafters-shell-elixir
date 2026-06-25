defmodule Commands.Jobs do
  @behaviour Commands.Command

  alias DataTypes.BackgroundJob

  @impl true
  def execute(_args) do
    jobs =
      JobsCache.get_all()

    case length(jobs) do
      0 ->
        :ok

      length when length >= 1 ->
        [job | _] = jobs

        command =
          String.split(job.command_str, "/")
          |> Enum.at(-1)

        IO.puts("[#{job.job_number}]+  Running                 #{command}")
    end
  end
end
