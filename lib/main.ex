defmodule CLI do
  def main(_args) do
    IO.write("$ ")
  end

  defp listen do
    input = IO.gets("") |> String.trim()

  end
end
