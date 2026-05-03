defmodule Commands.CD do
  @behaviour Commands.Command

  def execute(args) do
    System.cmd("cd", [args])
  end
end
