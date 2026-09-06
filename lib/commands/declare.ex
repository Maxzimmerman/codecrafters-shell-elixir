defmodule Commands.Declare do
  @behaviour Commands.Command

  def execute(["-p", variable_name | _]) do
    case VariableCache.get_one(variable_name) do
      :not_found -> IO.puts("declare: #{variable_name}: not found")
    end
  end

  def execute(args) do
  end
end
