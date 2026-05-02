defmodule Commands.Execute do
  @behaviour Commands.Command
  def execute([path | input]) do
    IO.inspect(input)
    port = Port.open({:spawn_executable, path}, [
      :binary,
      :exit_status,
      :use_stdio,
      args: input
    ])

    receive do
      {^port, {:data, data}} -> IO.puts("executed with #{inspect(data)}")
      {^port, {:exit_status, code}} -> IO.puts("finished")
    end
  end
end
