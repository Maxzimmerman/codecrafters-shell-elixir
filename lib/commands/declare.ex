defmodule Commands.Declare do
  @behaviour Commands.Command

  def execute(["-p", variable_name | _]) do
    case VariableCache.get_one(variable_name) do
      :not_found -> IO.puts("declare: #{variable_name}: not found")
      value -> IO.puts(value)
    end
  end

  def execute([input]) do
    [key, val] = String.split(input, "=")
    VariableCache.add_one(key, val)
  end
end
