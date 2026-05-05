defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([path, args]) do
    if Enum.member?(args, ">") do
      IO.puts("CALLED EXECUTE with > #{inspect(args)}")
    end
    IO.puts("CALLED EXECUTE #{inspect(args)}")
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :exit_status,
        :use_stdio,
        arg0: Path.basename(path),
        args: args
      ])

    loop(port)
  end

  def execute(_args), do: :error

  defp loop(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        loop(port)

      {^port, {:exit_status, _code}} ->
        :ok
    end
  end
end
