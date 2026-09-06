defmodule Commands.Declare do
  @behaviour Commands.Command

  def execute(["-p", variable_name | _]) do
    IO.inspect(variable_name)
  end

  def execute(args) do
  end
end
