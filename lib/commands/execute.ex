defmodule Commands.Execute do
  @bahaviour Commands.Command

  def execute(args) do
    IO.inspect(args)
  end
end
