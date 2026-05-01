defmodule Commands.Echo do
  @behaviour Commands.Command

  def execute(args) do
    IO.puts(inspect(args))
  end
end
