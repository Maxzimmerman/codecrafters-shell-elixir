defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([path, args]) do
      IO.inspect(args, lable: "TEST ARGS")
    if Enum.member?(args, ">") do
      [_, read_dir, _, write_dir] = args

      port =
        Port.open({:spawn_executable, path}, [
          :binary,
          :exit_status,
          :use_stdio,
          arg0: Path.basename(path),
          args: args
        ])

      loop(port, read_dir, write_dir)
    else
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
  end

  def execute(_args), do: :error

  defp loop(port, input_file, output_file) do
    receive do
      {^port, {:data, data}} ->
        IO.inspect(data, label: "TEST")
        loop(port, input_file, output_file)

      {^port, {:exit_status, _code}} ->
        :ok
    end
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
end
