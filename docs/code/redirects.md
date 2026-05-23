# Redirects — `extract_*_redirect/1` and `with_stdout_redirect/2`

Three related helpers that together implement `>`, `>>`, `1>`, `1>>`, `2>`,
and `2>>`.

## `extract_stdout_redirect/1` and `extract_stderr_redirect/1`

`lib/main.ex:153-173`

```elixir
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
```

### What they do

Walk the token list, find a redirect operator, split off the operator and the
filename that follows. Return:

- `tokens` with the operator and target removed
- `{filename, :write | :append}` describing the redirect (or `nil` if no
  redirect was found)

### How `Enum.split_while` is being used

`Enum.split_while(list, fun)` walks the list until `fun` returns false, then
returns `{before, rest}`. The first non-matching element is the head of `rest`.

So `Enum.split_while(tokens, &(&1 not in ["2>", "2>>"]))` returns:

- `before` — everything up to (but not including) the first `2>` or `2>>`
- `rest` — starts with that operator (if found) or is `[]`

### The match clauses

```elixir
case ... do
  {before, [op, file | rest]} ->
    # Found an operator AND a filename after it
    mode = if op == "2>>", do: :append, else: :write
    {before ++ rest, {file, mode}}

  {tokens, _} ->
    # Either no operator at all, OR operator with no filename
    {tokens, nil}
end
```

The first clause requires `rest` to have at least two elements: the operator
and the filename. If the input ends with a bare `2>` (no filename after), the
match fails and we fall through to the default — effectively ignoring the
malformed redirect.

### Why `:write` vs `:append`

| Operator | Mode | Effect |
| --- | --- | --- |
| `>` or `1>` | `:write` | Create or truncate the file |
| `>>` or `1>>` | `:append` | Create if missing; append to existing content |
| `2>` | `:write` | (stderr) create or truncate |
| `2>>` | `:append` | (stderr) create if missing; append |

The mode is just a tag at this stage — actual file operations happen in
`dispatch/2` and `with_stdout_redirect/2`.

### Example

```elixir
extract_stdout_redirect(["echo", "hi", ">", "out.log"])
#=> {["echo", "hi"], {"out.log", :write}}

extract_stdout_redirect(["echo", "hi"])
#=> {["echo", "hi"], nil}

extract_stdout_redirect(["echo", "hi", ">>", "log.txt"])
#=> {["echo", "hi"], {"log.txt", :append}}
```

### Limitations

- Only finds the **first** redirect of each type. `echo hi > a > b` is
  treated as `{["echo", "hi", ">", "b"], {"a", :write}}` (the second `>`
  becomes part of the args, which is wrong). Real shells handle this by
  using the last redirect.
- Doesn't handle interleaved redirects with arguments cleanly. For now this
  matches what the tests require.

## `with_stdout_redirect/2`

`lib/main.ex:175-189`

```elixir
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
```

### What it does

Run `fun` with the current process's stdout redirected to `path`. If `nil`,
no redirect — just call the function.

### The group-leader swap

The key line is `Process.group_leader(self(), file)`. In Elixir, `IO.write`
sends a message to the calling process's group leader. The group leader is a
process that handles the actual I/O. By swapping ours to a file-IO server,
we redirect all `IO.write` calls from our process.

See [LEARNING.md §7](../LEARNING.md#7-group-leaders-and-io-redirection) for
the full explanation.

### The `try/after` pattern

```elixir
try do
  fun.()
after
  Process.group_leader(self(), old_gl)
  File.close(file)
end
```

`after` runs whether the function returned normally or raised an exception.
This guarantees the group leader is restored and the file is closed even if
the command crashes.

Without this guarantee, an error inside `fun.()` could leave our REPL
permanently redirected to a closed file, breaking all subsequent commands.

### `File.open` returns an IO server, not just a file handle

```elixir
{:ok, file} = File.open(path, [mode])
```

`file` here is **a PID** — Elixir's `File.open/2` (without `:raw` option)
spawns a new IO server process that wraps the file. That process can be used
anywhere an IO device is expected, including as a group leader.

If you tried this with a raw fd (the C-style file handle), it wouldn't work
as a group leader. The Erlang/Elixir convention of IO-server-as-process is
what makes this trick possible.

### Flow

```
dispatch("echo", ["hi"], stdout_redirect={"out.log", :write})
  with_stdout_redirect({"out.log", :write}, fn -> run_command(...) end)
    File.mkdir_p!(Path.dirname("out.log"))  # ensure parent dir exists
    File.open("out.log", [:write])           # spawn IO server, get PID
    old_gl = Process.group_leader()           # save current (terminal)
    Process.group_leader(self(), file)        # swap to file IO server
    try
      run_command(...)
        Echo.execute(["hi"])
          IO.puts("hi")
            → message to current GL (= file IO server)
            → file IO server writes "hi\n" to out.log
    after
      Process.group_leader(self(), old_gl)    # restore
      File.close(file)                         # close file
```

## Related concepts

- [LEARNING.md §7](../LEARNING.md#7-group-leaders-and-io-redirection) —
  group-leader-based I/O routing
- [code/dispatch.md](dispatch.md) — caller that orchestrates redirect setup
- [code/tokenize.md](tokenize.md) — produces the token list these functions
  consume
