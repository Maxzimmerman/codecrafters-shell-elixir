defmodule CLI do
  alias Commands.Exit
  alias Commands.Echo
  alias Commands.Type

  @commands %{
    "exit" => Exit,
    "echo" => Echo,
    "type" => Type
  }

  def main(_args) do
    listen()
  end

  defp listen do
    IO.write("$ ")
    input = IO.gets("")
    [command | input] = decode_console_input(input)

    try do
      command(command).execute(input)
    rescue
      e in KeyError -> IO.puts("#{command}: not found")
    catch
      _error -> IO.puts("#{command}: not found")
    end

    listen()
  end

  defp command(name) do
    Map.fetch!(@commands, name)
  end

  defp decode_console_input(input) do
    String.trim(input) |> String.split(" ")
  end
end
