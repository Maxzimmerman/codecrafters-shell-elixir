defmodule CLI do
  @commands []
  def main(_args) do
    IO.write("$ ")

    listen()
  end

  defp listen do
    input = IO.gets("") |> String.trim()

    case input do
      :eof -> IO.puts("bye")
      cmd ->
        if cmd in @commands do
          IO.puts("found")
        else
          IO.puts("#{cmd}: not found")
        end
    end

    listen()
  end
end
