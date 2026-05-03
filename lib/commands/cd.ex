defmodule Commands.CD do
  @behaviour Commands.Command

  def execute(args) do
    if Path.relative?(args) do
      cd_working_dir(args)
    else
      IO.puts("error: #{args}")
    end
  end

  defp cd_working_dir(args) do
    case File.exists?(args) do
      true ->
        File.cd(args)
      false ->
        IO.puts("cd: #{args}: No such file or directory")
    end
  end
end
