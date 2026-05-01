defmodule CLI do
  alias Commands.Exit

  @commands %{
    "exit" => Exit
  }

  def main(_args) do
    listen()
  end

  defp listen do
    IO.write("$ ")
    input = IO.gets("") |> String.trim()

    case input do
      :eof ->
        IO.puts("bye")

      cmd ->
        try do
          command().execute()
        catch
          IO.puts("#{cmd}: not found")
        end
    end

    listen()
  end

  defp command(name) do
    Map.fetch!(@commands, name)
  end
end
