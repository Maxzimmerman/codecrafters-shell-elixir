defmodule CLI do
  @commands ["exit"]

  def main(_args) do
    listen()
  end

  defp listen do
    IO.write("$ ")
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
