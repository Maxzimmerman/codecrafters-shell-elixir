defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  @registered []

  def execute(["-p", executable | _] = args) do
    if executable in @registered do
      IO.write("")
    else
      IO.puts("complete: #{executable}: no completion specification")
    end
  end

  def execute(["-C", path, executable_name | _] = args) do
    if executable_name in @registered do
      IO.write("")
    else
      IO.puts("complete: #{executable}: no completion specification")
    end
  end
end
