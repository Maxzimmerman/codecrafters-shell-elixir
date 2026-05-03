defmodule Commands.PWD do
  @behaviour Commands.Command

  def execute(_args) do
    IO.puts(Path.absname(""))
  end
end
