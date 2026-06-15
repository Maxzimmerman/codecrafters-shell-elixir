defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  def execute(args) do
    handle_complete(args)
  end

  def handle_complete(["-p", executable | _] = _args) do
    with true <- executable_in_state?(executable),
         {:ok, path} <- get_path(executable) do
      IO.puts("complete -C '#{path}' #{executable}")
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

  defp executable_in_state?(executable),
    do: RegisteredCompletionScriptsCache.get_with_name(executable)

  defp get_path(executable) do
    case RegisteredCompletionScriptsCache.get_with_name(executable) do
      %{} -> IO.puts("complete: #{executable}: no completion specification")
      path -> {:ok, path}
    end
  end
end
