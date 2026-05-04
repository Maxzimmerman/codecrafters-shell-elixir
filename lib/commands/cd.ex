defmodule Commands.CD do
  @behaviour Commands.Command

  def execute([path | _]) do
    normalised_path = normalise_path(path)

    cd_working_dir(Path.relative(normalised_path))
  end

  def execute(_), do: :error

  defp cd_working_dir(args) do
    case File.exists?(args) do
      true ->
        File.cd(args)

      false ->
        IO.puts("cd: #{args}: No such file or directory")
    end
  end

  defp normalise_path(path) do
    if String.contains?(path, "~") do
      Path.expand(path)
    else
      path
    end
  end
end
