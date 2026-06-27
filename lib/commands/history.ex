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
    |> IO.inspect()
  end
end
