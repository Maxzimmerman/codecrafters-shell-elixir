defmodule Commands.Type do
  @behaviour Commands.Command

  import Bitwise

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
        res =
          System.get_env("PATH")
          |> String.split(":")
          |> Enum.map(&Path.join(&1, command))
          |> Enum.find(&executable?/1)

        if res do
          IO.puts("#{command} is #{res}")
        else
          IO.puts("#{command}: not found")
        end
    end
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} ->
        (mode &&& 0o111) != 0

      {:error, _} ->
        false
    end
  end
end
