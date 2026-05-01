defmodule CLI do
  alias Commands.Exit
  alias Commands.Echo

  @commands %{
    "exit" => Exit,
    "echo" => Echo
  }

  def main(_args) do
    listen()
  end

  defp listen do
    IO.write("$ ")
    input = IO.gets("") |> String.trim()
    IO.inspect(input)

    case input do
      :eof ->
        IO.puts("bye")

      cmd ->
        try do
          command(cmd).execute()
        catch
          _error -> IO.puts("#{cmd}: not found")
        end
    end

    listen()
  end

  defp command(name) do
    Map.fetch!(@commands, name)
  end
end
