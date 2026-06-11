defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  @registered []

  def execute(args) do
    {:ok, pid} = RegisteredCompletionScriptsCache.start_link()
    handle_complete(args, pid)
  end

  def handle_complete(["-p", executable | _] = args, pid) do
    if executable in state() do
      IO.write("")
    else
      IO.puts("complete: #{executable}: no completion specification")
    end
  end

  def handle_complete(["-C", path, executable_name | _] = args, pid) do
    if executable_name not in state() do
      RegisteredCompletionScriptsCache.set_state(executable_name)
    end

    if executable_name in @registered do
      IO.write("")
    else
      IO.puts("complete: #{executable_name}: no completion specification")
    end
  end

  defp state do
    RegisteredCompletionScriptsCache.get_state()
  end
end
