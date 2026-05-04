defmodule CLI do
  alias Commands.Exit
  alias Commands.Echo
  alias Commands.Type
  alias Commands.PWD
  alias Commands.CD
  alias Commands.Execute

  alias Commands

  @commands %{
    "exit" => Exit,
    "echo" => Echo,
    "type" => Type,
    "pwd" => PWD,
    "cd" => CD,
    "" => Execute
  }

  def main(_args) do
    listen()
  end

  defp listen do
    IO.write("$ ")
    input = IO.gets("")
    [command | input] = decode_console_input(input)

    case Commands.executable_in_path?(command) do
      {:ok, res} ->
        Execute.execute([res, input])

      {:error, :no_exe} ->
        try do
          command(command).execute(input)
        rescue
          _e in KeyError -> IO.puts("#{command}: not found")
        catch
          _error -> IO.puts("#{command}: not found")
        end
    end

    listen()
  end

  defp command(name) do
    Map.fetch!(@commands, name)
  end

  defp decode_console_input(input) do
    input
    |> String.trim_trailing("\n")
    |> tokenize([], "", false, false)
  end

  defp tokenize("", tokens, "", false, false), do: Enum.reverse(tokens)
  defp tokenize("", tokens, current, false, true), do: Enum.reverse([current | tokens])

  defp tokenize(<<"'", rest::binary>>, tokens, current, false, _has_token) do
    tokenize(rest, tokens, current, true, true)
  end

  defp tokenize(<<"'", rest::binary>>, tokens, current, true, has_token) do
    tokenize(rest, tokens, current, false, has_token)
  end

  defp tokenize(<<c::utf8, rest::binary>>, tokens, current, true, _has_token) do
    tokenize(rest, tokens, current <> <<c::utf8>>, true, true)
  end

  defp tokenize(<<c, rest::binary>>, tokens, current, false, has_token) when c in [?\s, ?\t] do
    if has_token do
      tokenize(rest, [current | tokens], "", false, false)
    else
      tokenize(rest, tokens, current, false, false)
    end
  end

  defp tokenize(<<c::utf8, rest::binary>>, tokens, current, false, _has_token) do
    tokenize(rest, tokens, current <> <<c::utf8>>, false, true)
  end
end
