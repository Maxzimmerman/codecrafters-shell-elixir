defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([command_path, args, stderr_file]) when is_binary(stderr_file) do
    cmd_string =
      ([command_path | args] |> Enum.map(&shell_escape/1) |> Enum.join(" ")) <>
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

  def execute([path, args]) do
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

  defp shell_escape(s), do: "'" <> String.replace(s, "'", ~S('\'')) <> "'"
end
