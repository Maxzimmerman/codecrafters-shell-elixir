defmodule Commands.CD do
  @behaviour Commands.Command

  def execute(args) do
    case File.exists?(args) do
      true ->
        File.cd(args)
      false ->
        IO.puts("cd: #{args}: No such file or directory")
    end
  end
end
