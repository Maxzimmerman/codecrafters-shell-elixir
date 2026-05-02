defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([path | [input]]) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :exit_status,
        :use_stdio,
        args: input
      ])

    loop(port)

    IO.puts("Program was passed #{Enum.count(input) + 1} args (including program name).")
  end

  defp loop(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        loop(port)

      {^port, {:exit_status, _code}} ->
        :ok
    end
  end

  def execute(_args), do: :error

  def encode_exe_output(data) do
    [data | inputs] = String.split(data, "\n")

    for input <- inputs do
      IO.puts(input)
    end
  end
end
