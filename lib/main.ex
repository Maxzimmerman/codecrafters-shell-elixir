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
    :io.setopts(:standard_io, binary: true)
    listen()
  end

  defp read_byte do
    case :io.get_chars(:standard_io, ~c"", 1) do
      <<b>> -> b
      :eof -> :eof
      {:error, _} -> :eof
    end
  end

  defp read_line(buf) do
    case read_byte() do
      :eof ->
        if buf == "", do: :eof, else: buf

      ?\r ->
        IO.write("\r\n")
        buf

      ?\n ->
        IO.write("\r\n")
        buf

      ?\t ->
        buf |> handle_tab() |> read_line()

      127 ->
        buf |> backspace() |> read_line()

      8 ->
        buf |> backspace() |> read_line()

      3 ->
        IO.write("^C\r\n")
        System.halt(130)

      4 ->
        if buf == "", do: :eof, else: read_line(buf)

      b when is_integer(b) ->
        char = <<b>>
        IO.write(char)
        read_line(buf <> char)
    end
  end

  defp backspace(""), do: ""

  defp backspace(buf) do
    IO.write("\b \b")
    String.slice(buf, 0..-2//1)
  end

  defp handle_tab(buf) do
    matches =
      Enum.filter(@builtins ++ Commands.executables_in_path(), &String.starts_with?(&1, buf))
      |> Enum.uniq()

    case matches do
      [match] when buf != "" ->
        suffix = String.replace_prefix(match <> " ", buf, "")
        IO.write(suffix)
        match <> " "

      found_matches when length(found_matches) > 1 ->
        IO.puts("more thena one")

      _ ->
        IO.puts("WRONG for: #{buf} #{inspect(@builtins ++ Commands.executables_in_path())}")
        IO.puts("\x07")
        buf
    end
  end

  defp listen do
    IO.write("$ ")

    case read_line("") do
      :eof ->
        :ok

      input ->
        process_line(input)
        listen()
    end
  end

  defp process_line(input) do
    case decode_console_input(input) do
      [] ->
        :ok

      [command | input] ->
        dispatch(command, input)
    end
  end

  defp dispatch(command, input) do
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
