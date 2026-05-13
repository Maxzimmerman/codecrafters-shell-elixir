defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([command_path, [flag, read_file, op, output_file]] = _input) do
    if op in [">", "1>"] do
      port =
        Port.open({:spawn_executable, command_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          arg0: Path.basename(command_path),
          args: [flag, read_file]
        ])

      loop(port, output_file, [])
    end
  end

  def execute([path, args] = _input) do
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

  defp loop(port, output_file, output_data) do
    receive do
      {^port, {:data, data}} ->
        loop(port, output_file, [output_data | data])

      {^port, {:exit_status, _code}} ->
        {:ok, file} = File.open(output_file, [:write])
        IO.binwrite(file, output_data)
        File.close(file)
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
