defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([path | [input]]) do
    port = Port.open({:spawn_executable, path}, [
      :binary,
      :exit_status,
      :use_stdio,
      args: input
    ])

    IO.puts("Program was passed #{Enum.count(input) + 1} args (including program name).")

    receive do
      {^port, {:data, data}} -> encode_exe_output(data)
      {^port, {:exit_status, _code}} -> :finished
    end
  end

  def execute(_args), do: :error

  def encode_exe_output(data) do
    data = String.split(data, "\n")
    IO.puts("#{inspect(data)}")
  end
end
