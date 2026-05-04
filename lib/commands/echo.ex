defmodule Commands.Echo do
  @behaviour Commands.Command

  def execute(args) do
    if String.at(args, 0) == "'" and String.at(args, -1) == "'" do
      IO.inspect(Enum.join(String.slice(args, 1..-2), " "))
    end
  end
end
