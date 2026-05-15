defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([path, args] = _input) do
    case extract_stderr_redirect(args) do
      {clean_args, nil} ->
        spawn_normally(path, clean_args)

      {clean_args, stderr_file} ->
        File.mkdir_p!(Path.dirname(stderr_file))

        cmd_string =
          ([path | clean_args] |> Enum.map(&shell_escape/1) |> Enum.join(" ")) <>
            " 2> " <> shell_escape(stderr_file)

        sh = System.find_executable("sh")

        port =
          Port.open({:spawn_executable, sh}, [
            :binary,
            :exit_status,
            :use_stdio,
            arg0: "sh",
            args: ["-c", cmd_string]
          ])

        loop(port)
    end
  end

  def execute([command_path, [flag, read_file, op, output_file]] = _input)
      when op in [">", "1>"] do
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

  def collect_stdout(os_pid) do
    case Enum.split_while(args, &(&1 != "2>")) do
      {before, ["2>", file | _]} -> {before, file}
      {before, []} -> {before, nil}
    end
  end

  defp shell_escape(s), do: "'" <> String.replace(s, "'", ~S('\'')) <> "'"
end
