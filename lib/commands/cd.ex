defmodule Commands.CD do
  @behaviour Commands.Command

  def execute(args) do
    File.cd(args)
  end
end
