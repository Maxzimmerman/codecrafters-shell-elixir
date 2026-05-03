defmodule Commands.CD do
  @behaviour Commands.Command

  def execute([path | _]) do
    normalised_path = normalise_path(path)
    if Path.relative(normalised_path) do
      cd_working_dir(normalised_path)
    else
      IO.puts("error: #{normalised_path}")
    end
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
      expanded_path = Path.expand(path)
      expanded_path
    else
      path
    end
  end
end
