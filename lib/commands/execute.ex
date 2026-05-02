defmodule Commands.Execute do
  @bahaviour Commands.Command

  def execute(args) do
    IO.inspect(args, label: "Execute")
  end
end
