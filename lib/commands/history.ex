defmodule Commands.History do
  @behaviour Commands.Command

  def execute(_) do
    HistoryCache.get_all()
    |> print_history()
  end

  def print_history(history) do
    history
    |> Enum.reverse()
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.with_index(fn line, index ->
      IO.puts("#{index} #{line}")
    end)
  end
end
