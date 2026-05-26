defmodule Commands do
  import Bitwise

  def executable_in_path?(command) do
    res =
      System.get_env("PATH")
      |> String.split(":")
      |> Enum.map(&Path.join(&1, command))
      |> Enum.find(&executable?/1)

    if res do
      {:ok, res}
    else
      {:error, :no_exe}
    end
  end

  def executables_in_path do
    executables_in_path =
      System.get_env("PATH", "")
      |> String.split(":", trim: true)
      |> Enum.flat_map(&list_executables_for_dir(&1))
      |> Enum.uniq()

    executables_in_path
  end

  def list_executables_for_dir(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.filter(files, &executable?(Path.join(dir, &1)))

      {:error, _reason} ->
        []
    end
  end

  def longest_common_prefix([]), do: ""

  def longest_common_prefix(words) do
    min_len = Enum.map(words, &length(&1)) |> Enum.min()
    first = hd(words)

    0..(min_len - 1)//1
    |> Enum.reduce_while("", fn i, acc ->
      ch = String.at(first, i)

      if Enum.all?(words, &(String.at(&1, i) == ch)),
        do: {:cont, acc <> ch},
        else: {:halt, acc}
    end)
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} ->
        (mode &&& 0o111) != 0

      {:error, _} ->
        false
    end
  end
end
