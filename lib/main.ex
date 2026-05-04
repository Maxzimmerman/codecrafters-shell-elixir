defmodule CLI do
  alias Commands.Exit
  alias Commands.Echo
  alias Commands.Type
  alias Commands.PWD
  alias Commands.CD
  alias Commands.Execute

  alias Commands

  @commands %{
    "exit" => Exit,
    "echo" => Echo,
    "type" => Type,
    "pwd" => PWD,
    "cd" => CD,
    "" => Execute
  }

  def main(_args) do
    listen()
  end

  defp listen do
    IO.write("$ ")
    input = IO.gets("")
    [command | input] = decode_console_input(input)

    case Commands.executable_in_path?(command) do
      {:ok, res} ->
        Execute.execute([res, input])

      {:error, :no_exe} ->
        try do
          command(command).execute(input)
        rescue
          _e in KeyError -> IO.puts("#{command}: not found")
        catch
          _error -> IO.puts("#{command}: not found")
        end
    end

    listen()
  end

  defp command(name) do
    Map.fetch!(@commands, name)
  end

  defp decode_console_input(input) do
    if String.at(input, 0) == "'" and String.at(input, -1) == "'" do
      IO.puts("is quoted")
      IO.puts(Enum.join(String.slice(input, 1..-2), " "))
    end
    String.trim(input) |> String.split(" ")
  end
end
