defmodule Commands.CD do
  @behaviour Commands.Command

  def execute(args) do
    IO.puts(args)
    System.cmd("cd", [args])
  end
end
