defmodule Commands.History do
  @behaviour Commands.Command

  def execute(_) do
    IO.inspect(HistoryCache.get_all())
  end
end
