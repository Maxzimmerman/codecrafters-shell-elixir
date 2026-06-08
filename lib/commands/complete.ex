defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  def execute(args) do
    IO.inspect(args)
  end
end
