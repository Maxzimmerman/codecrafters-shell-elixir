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
    |> tokenize([], "", :none, false)
  end

  defp tokenize("", tokens, "", :none, false), do: Enum.reverse(tokens)
  defp tokenize("", tokens, current, :none, true), do: Enum.reverse([current | tokens])

  defp tokenize(<<"'", rest::binary>>, tokens, current, :none, _has_token) do
    tokenize(rest, tokens, current, :single, true)
  end

  defp tokenize(<<"'", rest::binary>>, tokens, current, :single, has_token) do
    tokenize(rest, tokens, current, :none, has_token)
  end

  defp tokenize(<<"\"", rest::binary>>, tokens, current, :none, _has_token) do
    tokenize(rest, tokens, current, :double, true)
  end

  defp tokenize(<<"\"", rest::binary>>, tokens, current, :double, has_token) do
    tokenize(rest, tokens, current, :none, has_token)
  end

  defp tokenize(<<"\\", c::utf8, rest::binary>>, tokens, current, :double, _has_token)
       when c in [?$, ?`, ?", ?\\] do
    tokenize(rest, tokens, current <> <<c::utf8>>, :double, true)
  end

  defp tokenize(<<c::utf8, rest::binary>>, tokens, current, mode, _has_token)
       when mode in [:single, :double] do
    tokenize(rest, tokens, current <> <<c::utf8>>, mode, true)
  end

  defp tokenize(<<"\\", c::utf8, rest::binary>>, tokens, current, :none, _has_token) do
    tokenize(rest, tokens, current <> <<c::utf8>>, :none, true)
  end

  defp tokenize(<<c, rest::binary>>, tokens, current, :none, has_token) when c in [?\s, ?\t] do
    if has_token do
      tokenize(rest, [current | tokens], "", :none, false)
    else
      tokenize(rest, tokens, current, :none, false)
    end
  end

  defp tokenize(<<c::utf8, rest::binary>>, tokens, current, :none, _has_token) do
    tokenize(rest, tokens, current <> <<c::utf8>>, :none, true)
  end
end
