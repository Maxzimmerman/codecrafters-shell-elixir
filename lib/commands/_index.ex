defmodule Commands do
  import Bitwise

  def look_for_executable(command) do
    System.get_env("PATH")
    |> String.split(":")
    |> Enum.map(&Path.join(&1, command))
    |> Enum.find(&executable?/1)
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
