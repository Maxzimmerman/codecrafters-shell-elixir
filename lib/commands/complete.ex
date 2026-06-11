defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  @registered []

  def execute(args) do
    {:ok, pid} = RegisteredCompletionScriptsCache.start_link()
    handle_complete(args, pid)
  end

  def handle_complete(["-p", executable | _] = args, pid) do
    if executable in @registered do
      IO.write("")
    else
      IO.puts("complete: #{executable}: no completion specification")
    end
  end

  def handle_complete(["-C", path, executable_name | _] = args, pid) do
    IO.puts("Called")
    script_map = %{executable_name => path}
    state = RegisteredCompletionScriptsCache.get_state()

    if script_map not in state do
      IO.puts("valid")
      RegisteredCompletionScriptsCache.set_state(executable_name)
      state = RegisteredCompletionScriptsCache.get_state()
    end

    if executable_name in @registered do
      IO.write("")
    else
      IO.puts("complete: #{executable_name}: no completion specification")
    end
  end
end
