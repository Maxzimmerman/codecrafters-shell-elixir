defmodule Commands.Type do
  @behaviour Commands.Command

  @build_in_command [
    "exit",
    "echo"
  ]

  def execute(args) do
    command = Enum.join(args)

    case command in @build_in_command do
      true ->
        IO.puts("#{command} is a shell buildin")
      false ->
        IO.puts("#{command}: not found")
    end
  end
end
