defmodule CLI do
  alias Commands.Exit
  alias Commands.Echo
  alias Commands.Type
  alias Commands.PWD
  alias Commands.CD
  alias Commands.Execute
  alias Commands.Complete
  alias Commands.Jobs
  alias Commands.History

  alias Commands

  @commands %{
    "exit" => Exit,
    "echo" => Echo,
    "type" => Type,
    "pwd" => PWD,
    "cd" => CD,
    "complete" => Complete,
    "jobs" => Jobs,
    "history" => History,
    "" => Execute
  }

  @builtins ~w(echo exit)

  # Entry point: switch stdin to binary mode, start the completion cache, enter REPL.
  def main(_args) do
    :io.setopts(:standard_io, binary: true)
    {:ok, _pid} = RegisteredCompletionScriptsCache.start_link()
    {:ok, _} = JobsCache.start_link()
    {:ok, _} = HistoryCache.start_link()

    listen()
  end

  # Read exactly one byte from stdin (returns the int code or :eof).
  defp read_byte do
    case :io.get_chars(:standard_io, ~c"", 1) do
      <<b>> -> b
      :eof -> :eof
      {:error, _} -> :eof
    end
  end

  # Byte-by-byte line reader; handles Enter, Tab, Backspace, Ctrl-C, Ctrl-D, printable chars.
  defp read_line(buf, tab_count, arrow_up_count) do
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
        if length(String.split(buf, " ")) > 1 do
          buf |> handle_file_completion_tab(tab_count) |> read_line(tab_count + 1, arrow_up_count)
        else
          buf |> handle_tab(tab_count) |> read_line(tab_count + 1, arrow_up_count)
        end

      127 ->
        buf |> backspace() |> read_line(tab_count, arrow_up_count)

      8 ->
        buf |> backspace() |> read_line(tab_count, arrow_up_count)

      3 ->
        IO.write("^C\r\n")
        System.halt(130)

      4 ->
        if buf == "", do: :eof, else: read_line(buf, tab_count, arrow_up_count)

      27 ->
        case {read_byte(), read_byte()} do
          {?[, ?A} ->
            handle_up(buf, arrow_up_count + 1) |> read_line(tab_count, arrow_up_count + 1)

          _ ->
            read_line(buf, tab_count, arrow_up_count + 1)
        end

      b when is_integer(b) ->
        char = <<b>>
        IO.write(char)
        read_line(buf <> char, tab_count, arrow_up_count)
    end
  end

  # Erase the last char from both the buffer and the terminal display.
  defp backspace(""), do: ""

  defp backspace(buf) do
    IO.write("\b \b")
    String.slice(buf, 0..-2//1)
  end

  # Recall the count-th most recent history entry: erase the current line
  # contents on screen, display the recalled command, and make it the new buffer.
  def handle_up(buf, count) do
    history = HistoryCache.get_all() |> Enum.map(&Enum.join(&1, " "))

    case Enum.at(history, count - 1) do
      nil ->
        IO.write("\a")
        buf

      recalled ->
        IO.write(String.duplicate("\b \b", String.length(buf)))
        IO.write(recalled)
        recalled
    end
  end

  # Tab pressed once the user has typed past the command name; routes to programmable or file completion.
  defp handle_file_completion_tab(buf, count) do
    parts = String.split(buf, " ")
    command = Enum.at(parts, 0)
    current_word = List.last(parts) || ""

    prev_word = if length(parts) >= 2, do: Enum.at(parts, -2), else: ""

    if Map.has_key?(RegisteredCompletionScriptsCache.get_state(), command) do
      handle_programmable_completion(buf, command, current_word, prev_word, count)
    else
      handle_default_file_completion(buf, current_word, count)
    end
  end

  # Invoke the -C completer script, parse its stdout into candidates, and apply standard tab behavior.
  defp handle_programmable_completion(buf, command, current_word, prev_word, count) do
    {:ok, path} = Commands.Complete.get_path(command)

    {output, _exit} =
      System.cmd(path, [command, current_word, prev_word],
        env: [
          {"COMP_LINE", buf},
          {"COMP_POINT", Integer.to_string(String.length(buf))},
          {"COMP_TYPE", "9"},
          {"COMP_KEY", "9"}
        ],
        stderr_to_stdout: false
      )

    matches = output |> String.split("\n", trim: true)

    case matches do
      [match] ->
        suffix = String.replace_prefix(match, current_word, "") <> " "
        IO.write(suffix)
        buf <> suffix

      found_matches when length(found_matches) > 1 and count == 0 ->
        prefix = Commands.longest_common_prefix(found_matches)
        suffix = String.replace_prefix(prefix, current_word, "")

        if suffix == "" do
          IO.write("\a")
          buf
        else
          IO.write(suffix)
          buf <> suffix
        end

      found_matches when length(found_matches) > 1 and count == 1 ->
        IO.write("\r\n" <> Enum.join(found_matches, "  ") <> "\r\n$ " <> buf)
        buf

      found_matches when length(found_matches) > 1 and count >= 1 ->
        IO.puts("here")
        buf

      _ ->
        IO.write("\a")
        buf
    end
  end

  # Complete the current word against filenames in the resolved directory.
  defp handle_default_file_completion(buf, current_word, count) do
    {dir, base} = split_path(current_word)

    file_matches =
      Commands.list_files_in_dir(dir)
      |> Enum.filter(&String.starts_with?(&1, base))
      |> Enum.uniq()
      |> Enum.sort()

    case file_matches do
      [match] when buf != "" ->
        suffix = String.replace_prefix(match, base, "")
        trailing = if File.dir?(Path.join(dir, match)), do: "/", else: " "
        IO.write(suffix <> trailing)
        buf <> suffix <> trailing

      found_matches when length(found_matches) > 1 and count == 0 ->
        prefix = Commands.longest_common_prefix(found_matches)
        suffix = String.replace_prefix(prefix, base, "")

        if suffix == "" do
          IO.write("\a")
          buf
        else
          IO.write(suffix)
          buf <> suffix
        end

      found_matches when length(found_matches) > 1 and count == 1 ->
        display =
          Enum.map_join(found_matches, "  ", fn match ->
            if File.dir?(Path.join(dir, match)), do: match <> "/", else: match
          end)

        IO.write("\r\n" <> display <> "\r\n$ " <> buf)
        buf

      _ ->
        IO.write("\a")
        buf
    end
  end

  # Split a path-like string into {directory, basename} for file completion lookup.
  defp split_path(file_name) do
    case String.split(file_name, "/") |> Enum.reverse() do
      [base] -> {".", base}
      [base | dir_parts] -> {(dir_parts |> Enum.reverse() |> Enum.join("/")) <> "/", base}
    end
  end

  # Tab pressed at the command position; complete against builtins + PATH executables.
  defp handle_tab(buf, count) do
    matches =
      Enum.filter(@builtins ++ Commands.executables_in_path(), &String.starts_with?(&1, buf))
      |> Enum.uniq()
      |> Enum.sort()

    case matches do
      [match] when buf != "" ->
        suffix = String.replace_prefix(match <> " ", buf, "")
        IO.write(suffix)
        match <> " "

      found_matches when length(found_matches) > 1 and count == 0 ->
        prefix = Commands.longest_common_prefix(found_matches)
        suffix = String.replace_prefix(prefix, buf, "")

        if suffix == "" do
          IO.write("\a")
          buf
        else
          IO.write(suffix)
          buf <> suffix
        end

      found_matches when length(found_matches) > 1 and count == 1 ->
        IO.write("\r\n" <> Enum.join(found_matches, "  ") <> "\r\n$ " <> buf)
        buf

      _ ->
        IO.write("\a")
        buf
    end
  end

  # REPL loop: print prompt, read a line, dispatch it, repeat until EOF.
  defp listen do
    JobsCache.clean_obsolete_jobs_and_print()
    IO.write("$ ")

    case read_line("", 0, 0) do
      :eof ->
        :ok

      input ->
        process_line(input)
        listen()
    end
  end

  # Tokenize the raw line into argv, then split off the command head for dispatch.
  defp process_line(input) do
    case decode_console_input(input) do
      [] ->
        :ok

      tokens ->
        if "|" in tokens do
          run_pipeline(tokens)
        else
          case tokens do
            [command, arg, "&" | rest] ->
              HistoryCache.add_one(tokens)
              dispatch_async(command, [arg] ++ rest)

            [command | args] ->
              HistoryCache.add_one(tokens)
              dispatch(command, args)
          end
        end
    end
  end

  # Build a shell pipeline string from argv tokens and run it via `sh -c`,
  # which handles stdin/stdout wiring, SIGPIPE, and live streaming for us.
  defp run_pipeline(tokens) do
    cmd_str =
      tokens
      |> Enum.map(fn
        "|" -> "|"
        tok -> shell_quote(tok)
      end)
      |> Enum.join(" ")

    sh = System.find_executable("sh")

    port =
      Port.open({:spawn_executable, sh}, [
        :binary,
        :exit_status,
        :use_stdio,
        arg0: "sh",
        args: ["-c", cmd_str]
      ])

    pipeline_loop(port)
  end

  defp pipeline_loop(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        pipeline_loop(port)

      {^port, {:exit_status, _code}} ->
        :ok
    end
  end

  defp shell_quote(s), do: "'" <> String.replace(s, "'", ~S('\'')) <> "'"

  # Strip redirect operators from argv, pre-create stderr file, run command under stdout redirect.
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
      run_command(command, input, stderr_redirect, false)
    end)
  end

  defp dispatch_async(command, input) do
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
      run_command(command, input, stderr_redirect, true)
    end)
  end

  # Run an external binary via Execute if found in PATH, otherwise dispatch to the builtin module.
  defp run_command(command, input, stderr_redirect, run_async) do
    case Commands.executable_in_path?(command) do
      {:ok, res} ->
        if stderr_redirect do
          Execute.execute([res, input, stderr_redirect], run_async)
        else
          Execute.execute([res, input], run_async)
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

  # Pull "2>" / "2>>" + filename out of argv; return {remaining_tokens, {file, mode} | nil}.
  defp extract_stderr_redirect(tokens) do
    case Enum.split_while(tokens, &(&1 not in ["2>", "2>>"])) do
      {before, [op, file | rest]} ->
        mode = if op == "2>>", do: :append, else: :write
        {before ++ rest, {file, mode}}

      {tokens, _} ->
        {tokens, nil}
    end
  end

  # Pull ">" / "1>" / ">>" / "1>>" + filename out of argv; return {remaining_tokens, {file, mode} | nil}.
  defp extract_stdout_redirect(tokens) do
    case Enum.split_while(tokens, &(&1 not in [">", "1>", ">>", "1>>"])) do
      {before, [op, file | rest]} ->
        mode = if op in [">>", "1>>"], do: :append, else: :write
        {before ++ rest, {file, mode}}

      {tokens, _} ->
        {tokens, nil}
    end
  end

  # Run fun with the group leader swapped to a file (so IO.* writes go there); no-op when nil.
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

  # Look up the builtin module that implements a given command name.
  defp command(name) do
    Map.fetch!(@commands, name)
  end

  # Parse the raw input line into a list of argv tokens with quote/escape handling.
  defp decode_console_input(input) do
    input
    |> String.trim_trailing("\n")
    |> tokenize([], "", :none, false)
  end

  # Char-by-char tokenizer; tracks current token, quote mode (:none/:single/:double), and "started a token" flag.
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
