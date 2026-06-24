defmodule Commands.Execute do
  @behaviour Commands.Command

  def execute([command_path, args, {stderr_file, mode}], false) when is_binary(stderr_file) do
    op = if mode == :append, do: " 2>> ", else: " 2> "

    cmd_string =
      ([command_path | args] |> Enum.map(&shell_escape/1) |> Enum.join(" ")) <>
        op <> shell_escape(stderr_file)

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

  def execute([path, args], false) do
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

  def execute([command_path, args, {stderr_file, mode}], true) when is_binary(stderr_file) do
    op = if mode == :append, do: " 2>> ", else: " 2> "

    cmd_string =
      ([command_path | args] |> Enum.map(&shell_escape/1) |> Enum.join(" ")) <>
        op <> shell_escape(stderr_file)

    sh = System.find_executable("sh")

    port =
      Port.open({:spawn_executable, sh}, [
        :binary,
        :exit_status,
        :use_stdio,
        arg0: "sh",
        args: ["-c", cmd_string]
      ])

    {:os_pid, pid} = :erlang.port_info(port, :os_pid)

    IO.puts("[1] #{pid}")

    spawn(fn -> loop(port) end)

    :ok
  end

  def execute([path, args], true) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :exit_status,
        :use_stdio,
        arg0: Path.basename(path),
        args: args
      ])

    {:os_pid, pid} = :erlang.port_info(port, :os_pid)

    IO.puts("[1] #{pid}")

    spawn(fn -> loop(port) end)

    :ok
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
