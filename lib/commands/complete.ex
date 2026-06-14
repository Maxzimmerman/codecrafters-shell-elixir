defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  @registered []

  def execute(args) do
    handle_complete(args)
  end

  def handle_complete(["-p", executable | _] = args) do
    if executable in state() do
      IO.write("")
    else
      IO.puts("complete: #{executable}: no completion specification")
    end
  end

  def handle_complete(["-C", path, executable_name | _] = args) do
    if executable_name not in state() do
      RegisteredCompletionScriptsCache.set_state(executable_name)
      IO.puts("complete -C #{path} #{executable_name}")
    else
      IO.write("")
    end
  end

  defp state do
    RegisteredCompletionScriptsCache.get_state()
  end
end
