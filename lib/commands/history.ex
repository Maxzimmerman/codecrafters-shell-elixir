defmodule Commands.History do
  @behaviour Commands.Command

  def execute(_) do
    HistoryCache.get_all()
    |> print_history()
  end

  def print_history(history) do
    history
    |> Enum.reverse()
    |> IO.inspect()
  end
end
