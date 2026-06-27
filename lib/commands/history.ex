defmodule Commands.History do
  @behaviour Commands.Command

  def execute([limit]) do
    HistoryCache.get_all()
    |> print_history_limit(limit |> String.to_integer())
  end

  def execute(_) do
    HistoryCache.get_all()
    |> print_history()
  end

  def print_history(history) do
    history
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.reverse()
    |> Enum.with_index(fn line, index ->
      IO.puts("#{index} #{line}")
    end)
  end

  def print_history_limit(history, limit) do
    history
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.reverse()
    |> Enum.take(limit)
    |> Enum.with_index(fn line, index ->
      IO.puts("#{index + 1} #{line}")
    end)
  end
end
