defmodule Commands.Echo do
  @behaviour Commands.Command

  def execute(args) do
    IO.inspect(args)
  end
end
