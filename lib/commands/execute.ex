defmodule Commands.Execute do
  @behaviour Commands.Command

  alias DataTypes.BackgroundJob

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

  def execute([command_path, args, {stderr_file, mode}], true)
      when is_binary(stderr_file) do
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

    redirect = op <> stderr_file
    command_str = Enum.join([Path.basename(command_path) | args], " ") <> redirect <> " &"
    length = JobsCache.get_all() |> length()
    job_number = length + 1

    JobsCache.add_job(%BackgroundJob{
      job_number: job_number,
      process_id: pid,
      command_str: command_str,
      status: :running
    })

    IO.puts("[#{job_number}] #{pid}")

    spawned = spawn(fn -> async_loop(port, pid) end)

    Port.connect(port, spawned)

    send(spawned, {:go, port})

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

    command_str = Enum.join([Path.basename(path) | args], " ") <> " &"
    length = JobsCache.get_all() |> length()
    job_number = length + 1

    JobsCache.add_job(%BackgroundJob{
      job_number: job_number,
      process_id: pid,
      command_str: command_str,
      status: :running
    })

    IO.puts("[#{job_number}] #{pid}")

    spawned = spawn(fn -> async_loop(port, pid) end)

    Port.connect(port, spawned)

    send(spawned, {:go, port})

    :ok
  end

  def execute(_args), do: :error

  defp async_loop(port, pid) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        async_loop(port, pid)

      {^port, {:exit_status, _code}} ->
        JobsCache.pause_job(pid)
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

  defp shell_escape(s), do: "'" <> String.replace(s, "'", ~S('\'')) <> "'"
end
