defmodule Commands.Echo do
  @behaviour Commands.Command

  def execute(args) do
    case Enum.split_while(args, fn a -> a not in [">", "1>", ">>", "1>>"] end) do
      {words, [op, file | _]} when op in [">>", "1>>"] ->
        File.write!(file, Enum.join(words, " ") <> "\n", [:append])

      {words, [op, file | _]} when op in [">", "1>"] ->
        File.write!(file, Enum.join(words, " ") <> "\n")

      {words, []} ->
        IO.puts(Enum.join(words, " "))
    end
  end
end
