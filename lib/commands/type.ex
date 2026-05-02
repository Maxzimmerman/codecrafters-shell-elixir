defmodule Commands.Type do
  @behaviour Commands.Command

  import Bitwise

  alias Commands

  @build_in_command [
    "exit",
    "echo",
    "type"
  ]

  def execute(args) do
    command = Enum.join(args)

    case command in @build_in_command do
      true ->
        IO.puts("#{command} is a shell builtin")

      false ->
        res = Commands.look_for_executable(command)

        if res do
          IO.puts("#{command} is #{res}")
        else
          IO.puts("#{command}: not found")
        end
    end
  end
end
