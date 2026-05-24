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

  def executables_in_path, do: System.get_env("PATH") |> String.split(":")

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} ->
        (mode &&& 0o111) != 0

      {:error, _} ->
        false
    end
  end
end
