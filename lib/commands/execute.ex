defmodule Commands.Execute do
  @behaviour Commands.Command
  def execute([path | [input]]) do
    port = Port.open({:spawn_executable, path}, [
      :binary,
      :exit_status,
      :use_stdio,
      args: input
    ])

    IO.puts("Program was passed #{Enum.count(input) + 1} args (including program name)")

    receive do
      {^port, {:data, data}} -> :got_data
      {^port, {:exit_status, code}} -> :finished
    end
  end
end
