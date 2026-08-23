defmodule Commands.History do
  @behaviour Commands.Command

  def execute([limit]) do
    HistoryCache.get_all()
    |> print_history_limit(limit |> String.to_integer())
  end

  def execute(["-r", file_path]) do
    case File.read(file_path) do
      {:ok, content} ->
        save_multiple_in_cache(content)

      {:error, reason} ->
        IO.puts("Failed to read file: #{reason}")
    end
  end

  def execute(["-w", file_path]) do
    with {:ok, file} <- File.open(file_path, [:write]) do
      HistoryCache.get_all()
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.reverse()
      |> Enum.each(fn item ->
        IO.write(file, item <> "\n")
      end)

      File.close(file)
    end
  end

  def execute(["-a", file_path]) do
    with {:ok, file} <- File.open(file_path, [:append]) do
      (get_comments_which_are_not_in_file(file_path) ++ ["history -a #{file_path}"])
      |> Enum.each(fn item ->
        IO.write(file, item <> "\n")
      end)

      File.close(file)
    end
  end

  defp get_comments_which_are_not_in_file(file_path) do
    with {:ok, content} <- File.read(file_path) do
      content =
        content
        |> String.split("\n", trim: true)
        |> Enum.map(fn item -> String.replace(item, "\n", " ") end)

      HistoryCache.get_all()
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.reverse()
      |> Enum.filter(fn command ->
        command not in content
      end)
    end
  end

  def execute(_input) do
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

  defp format_index(index) do
    index |> Integer.to_string() |> String.pad_leading(5)
  end

  defp save_multiple_in_cache(list) do
    list
    |> String.split("\n", trim: true)
    |> Enum.map(fn item -> String.replace(item, "\n", " ") end)
    |> Enum.each(fn item -> HistoryCache.add_one([item]) end)
  end
end
