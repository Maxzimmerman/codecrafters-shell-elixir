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

  @builtins ~w(echo exit)

  def main(_args) do
    :io.setopts(:standard_io, expand_fun: &expand/1)
    listen()
  end

  defp expand(reverse_prefix) do
    word = reverse_prefix |> Enum.reverse() |> to_string()

    case Enum.filter(@builtins, &String.starts_with?(&1, word)) do
      [match] when word != "" ->
        insertion = String.replace_prefix(match <> " ", word, "")
        {:yes, String.to_charlist(insertion), []}

      _ ->
        {:no, ~c"", []}
    end
  end

  defp listen do
    input = IO.gets("$ ")

    [command | input] = decode_console_input(input)

    {input, stderr_redirect} = extract_stderr_redirect(input)
    {input, stdout_redirect} = extract_stdout_redirect(input)

    if stderr_redirect do
      {path, mode} = stderr_redirect
      File.mkdir_p!(Path.dirname(path))

      case mode do
        :write -> File.write!(path, "")
        :append -> File.touch!(path)
      end
    end

    with_stdout_redirect(stdout_redirect, fn ->
      run_command(command, input, stderr_redirect)
    end)

    listen()
  end

  defp run_command(command, input, stderr_redirect) do
    case Commands.executable_in_path?(command) do
      {:ok, res} ->
        if stderr_redirect do
          Execute.execute([res, input, stderr_redirect])
        else
          Execute.execute([res, input])
        end

      {:error, :no_exe} ->
        try do
          command(command).execute(input)
        rescue
          _e in KeyError -> IO.puts("#{command}: not found")
        catch
          _error -> IO.puts("#{command}: not found")
        end
    end
  end

  defp extract_stderr_redirect(tokens) do
    case Enum.split_while(tokens, &(&1 not in ["2>", "2>>"])) do
      {before, [op, file | rest]} ->
        mode = if op == "2>>", do: :append, else: :write
        {before ++ rest, {file, mode}}

      {tokens, _} ->
        {tokens, nil}
    end
  end

  defp extract_stdout_redirect(tokens) do
    case Enum.split_while(tokens, &(&1 not in [">", "1>", ">>", "1>>"])) do
      {before, [op, file | rest]} ->
        mode = if op in [">>", "1>>"], do: :append, else: :write
        {before ++ rest, {file, mode}}

      {tokens, _} ->
        {tokens, nil}
    end
  end

  defp with_stdout_redirect(nil, fun), do: fun.()

  defp with_stdout_redirect({path, mode}, fun) do
    File.mkdir_p!(Path.dirname(path))
    {:ok, file} = File.open(path, [mode])
    old_gl = Process.group_leader()
    Process.group_leader(self(), file)

    try do
      fun.()
    after
      Process.group_leader(self(), old_gl)
      File.close(file)
    end
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
