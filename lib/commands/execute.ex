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

    redirect = op <> stderr_file
    command_str = Enum.join([Path.basename(command_path) | args], " ") <> redirect <> " &"

    spawn_async_job(sh, "sh", ["-c", cmd_string], command_str)
  end

  def execute([path, args], true) do
    command_str = Enum.join([Path.basename(path) | args], " ") <> " &"
    spawn_async_job(path, Path.basename(path), args, command_str)
  end

  def execute(_args), do: :error

  # < --- PIPES --- >
  def execute_with_pipe([command_path, args, {stderr_file, mode}], false)
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

    loop_pipe(port)
  end

  def execute_with_pipe([path, args], false) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :exit_status,
        :use_stdio,
        arg0: Path.basename(path),
        args: args
      ])

    loop_pipe(port)
  end

  def execute_with_pipe([command_path, args, {stderr_file, mode}], true)
      when is_binary(stderr_file) do
    op = if mode == :append, do: " 2>> ", else: " 2> "

    cmd_string =
      ([command_path | args] |> Enum.map(&shell_escape/1) |> Enum.join(" ")) <>
        op <> shell_escape(stderr_file)

    sh = System.find_executable("sh")

    redirect = op <> stderr_file
    command_str = Enum.join([Path.basename(command_path) | args], " ") <> redirect <> " &"

    spawn_async_job_pipe(sh, "sh", ["-c", cmd_string], command_str)
  end

  def execute_with_pipe([path, args], true) do
    command_str = Enum.join([Path.basename(path) | args], " ") <> " &"
    spawn_async_job_pipe(path, Path.basename(path), args, command_str)
  end

  defp spawn_async_job(exe, arg0, args, command_str) do
    parent = self()

    spawn(fn ->
      port =
        Port.open({:spawn_executable, exe}, [
          :binary,
          :exit_status,
          :use_stdio,
          arg0: arg0,
          args: args
        ])

      {:os_pid, pid} = :erlang.port_info(port, :os_pid)
      send(parent, {:port_started, pid})
      async_loop(port, pid)
    end)

    receive do
      {:port_started, pid} ->
        length = JobsCache.get_all() |> length()
        job_number = length + 1

        JobsCache.add_job(%BackgroundJob{
          job_number: job_number,
          process_id: pid,
          command_str: command_str,
          status: :running
        })

        IO.puts("[#{job_number}] #{pid}")
        :ok
    end
  end

  def execute_pipe(_args), do: :error

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

  defp spawn_async_job_pipe(exe, arg0, args, command_str) do
    parent = self()

    spawn(fn ->
      port =
        Port.open({:spawn_executable, exe}, [
          :binary,
          :exit_status,
          :use_stdio,
          arg0: arg0,
          args: args
        ])

      {:os_pid, pid} = :erlang.port_info(port, :os_pid)
      send(parent, {:port_started, pid})
      async_loop_pipe(port, pid)
    end)

    receive do
      {:port_started, pid} ->
        length = JobsCache.get_all() |> length()
        job_number = length + 1

        JobsCache.add_job(%BackgroundJob{
          job_number: job_number,
          process_id: pid,
          command_str: command_str,
          status: :running
        })

        IO.puts("[#{job_number}] #{pid}")
        :ok
    end
  end

  defp async_loop_pipe(port, pid) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        async_loop_pipe(port, pid)

      {^port, {:exit_status, _code}} ->
        JobsCache.pause_job(pid)
        :ok
    end
  end

  defp loop_pipe(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        loop_pipe(port)

      {^port, {:exit_status, _code}} ->
        IO.puts("HITS")
        :ok
    end
  end

  defp shell_escape(s), do: "'" <> String.replace(s, "'", ~S('\'')) <> "'"
end
