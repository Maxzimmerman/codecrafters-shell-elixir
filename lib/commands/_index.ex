defmodule Commands do
  import Bitwise

  def executable_in_path?(command) do
    IO.inspect(System.get_env("PATH") |> String.split(":") |> Enum.map(&Path.join(&1, command), label: "YTESTSTSET"))
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

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mode: mode}} ->
        (mode &&& 0o111) != 0

      {:error, _} ->
        false
    end
  end
end
