defmodule Commands.Type do
  @behaviour Commands.Command

  alias Commands

  @build_in_command [
    "exit",
    "echo",
    "type",
    "pwd"
  ]

  def execute(args) do
    command = Enum.join(args)

    case command in @build_in_command do
      true ->
        IO.puts("#{command} is a shell builtin")

      false ->
        case Commands.executable_in_path?(command) do
          {:ok, res} ->
            IO.puts("#{command} is #{res}")

          {:error, :no_exe} ->
            IO.puts("#{command}: not found")
        end
    end
  end
end
