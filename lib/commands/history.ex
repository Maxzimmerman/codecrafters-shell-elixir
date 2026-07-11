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
    |> Enum.with_index(1)
    |> Enum.each(fn {line, index} ->
      IO.puts("#{format_index(index)}  #{line}")
    end)
  end

  def print_history_limit(history, limit) do
    lines =
      history
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.reverse()
      |> Enum.with_index(1)

    lines
    |> Enum.take(-limit)
    |> Enum.each(fn {line, index} ->
      IO.puts("#{format_index(index)}  #{line}")
    end)
  end

  def print_most_recent(history) do
    IO.puts("MOST RECENT")
    IO.inspect(history, label: "full history")

    lines =
      history
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.reverse()

    result =
      lines
      |> Enum.take(1)
      |> Enum.each(fn line ->
        IO.puts("#{line}")
      end)

    IO.inspect(result, label: "result")
    result
  end

  defp format_index(index) do
    index |> Integer.to_string() |> String.pad_leading(5)
  end
end
