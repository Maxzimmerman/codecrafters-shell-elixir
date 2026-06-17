defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  def execute(args) do
    handle_complete(args)
  end

  def handle_complete(["-p", executable | _]) do
    case get_path(executable) do
      {:ok, path} ->
        IO.puts("complete -C '#{path}' #{executable}")

      {:error, :not_found} ->
        IO.puts("complete: #{executable}: no completion specification")
    end
  end

  def handle_complete(["-C", path, executable_name | _] = _args) do
    if executable_name not in Map.keys(state()) do
      RegisteredCompletionScriptsCache.set_state(executable_name, path)
    end
  end

  def handle_complete(["-r", executable_name | _]) do
    if executable_name in Map.keys(state()) do
      RegisteredCompletionScriptsCache.delete_with_name(executable_name)
    end
  end

  defp state do
    RegisteredCompletionScriptsCache.get_state()
  end

  def get_path(executable) do
    case RegisteredCompletionScriptsCache.get_with_name(executable) do
      nil -> {:error, :not_found}
      %{} -> {:error, :not_found}
      path when is_binary(path) -> {:ok, path}
    end
  end
end
