defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  def execute(args) do
    handle_complete(args)
  end

  def handle_complete(["-p", executable | _] = _args) do
    if executable in Map.keys(state()) do
      path = RegisteredCompletionScriptsCache.get_with_name(executable)
      IO.puts("complete -C '#{path}' #{executable}")
    else
      IO.inspect(state())
      IO.puts("complete: #{executable}: no completion specification")
    end
  end

  def handle_complete(["-C", path, executable_name | _] = _args) do
    if executable_name not in state() do
      RegisteredCompletionScriptsCache.set_state(executable_name, path)
    end
  end

  defp state do
    RegisteredCompletionScriptsCache.get_state()
  end
end
