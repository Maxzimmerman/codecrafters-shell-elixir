defmodule Commands.Echo do
  @behaviour Commands.Command

  def execute(args) do
    IO.puts(Enum.join(args, " "))
  end
end
