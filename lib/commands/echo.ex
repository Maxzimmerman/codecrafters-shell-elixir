defmodule Commands.Echo do
  @behaviour Commands.Command

  def execute(args) do
    IO.inspect(args, label: "TEST")
    IO.puts(Enum.join(args, " "))
  end
end
