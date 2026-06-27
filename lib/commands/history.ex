defmodule Commands.History do
  @behaviour Commands.Command

  def execute([number]) do
    HistoryCache.get_all()
    |> Enum.reverse()
    |> Enum.take(number)
    |> print_history()
  end

  def execute(_) do
    HistoryCache.get_all()
    |> Enum.reverse()
    |> print_history()
  end

  def print_history(history) do
    history
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.with_index(fn line, index ->
      IO.puts("#{index} #{line}")
    end)
  end
end
