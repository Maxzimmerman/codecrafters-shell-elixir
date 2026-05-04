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
    trimmed_input = input |> String.trim()

    case String.split(trimmed_input, "") |> Enum.filter(&(&1 == "'")) |> Enum.count() do
      2 ->
        trimmed_input
        |> String.split("'")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.trim(&1))

      0 ->
        IO.inspect(trimmed_input |> String.split(" "))
        trimmed_input |> String.split(" ") |> Enum.map(&String.trim(&1))
    end
  end
end
