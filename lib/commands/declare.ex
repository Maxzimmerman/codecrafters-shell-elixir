defmodule Commands.Declare do
  @behaviour Commands.Command

  @key_regex ~r/^[a-zA-Z_]/

  def execute(["-p", variable_name | _]) do
    case VariableCache.get_one(variable_name) do
      :not_found -> IO.puts("declare: #{variable_name}: not found")
      {key, value} -> IO.puts("declare -- #{key}=\"#{value}\"")
    end
  end

  def execute([input]) do
    with [key, val] <- String.split(input, "="),
         true <- validate_key(key) do
      VariableCache.add_one(key, val)
    end
  end

  defp validate_key(key), do: Regex.match?(@key_regex, key)
end
