# `dispatch/2` — coordinating redirects and execution

`lib/main.ex:114-131`

```elixir
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
```

## What it does

Takes a tokenized command line and:

1. Strips redirect operators (`2>`, `2>>`, `>`, `>>`, `1>`, `1>>`) out of the
   args.
2. Pre-creates the redirect target files if needed.
3. Wraps `run_command` in a group-leader swap so its stdout goes to the right
   place.

## Step 1 — extract redirects

```elixir
{input, stderr_redirect} = extract_stderr_redirect(input)
{input, stdout_redirect} = extract_stdout_redirect(input)
```

After tokenization, the input list might look like:

```elixir
["hello", ">", "out.log"]
```

`extract_stdout_redirect/1` walks the list, finds `>`, splits off `out.log`,
returns:

- New `input` without the redirect operator and target: `["hello"]`
- `stdout_redirect`: `{"out.log", :write}`

Same idea for stderr (`2>` / `2>>`).

If no redirect operator is present, the returned tuple is `{input, nil}`.

See [code/redirects.md](redirects.md) for the implementation.

## Step 2 — pre-create stderr files

```elixir
if stderr_redirect do
  {path, mode} = stderr_redirect
  File.mkdir_p!(Path.dirname(path))

  case mode do
    :write -> File.write!(path, "")
    :append -> File.touch!(path)
  end
end
```

Why pre-create? Because the stderr redirect is handled differently from
stdout — it's passed through to `Execute` as part of the shell command
string (see [code/run_command.md](run_command.md)). The shell `sh -c "cmd 2>
file"` will create the file when needed, but only when the program actually
writes to stderr. If the program writes nothing, the file wouldn't exist —
and shell convention says `2> file` should always create/truncate the file.
So we do it explicitly upfront.

- `:write` mode: create the file empty (truncating any existing content).
- `:append` mode: touch the file (create if missing; leave existing content
  alone).

`File.mkdir_p!` makes the parent directory if necessary, so paths like
`logs/err.txt` work even if `logs/` doesn't exist.

## Step 3 — run the command inside a stdout redirect wrapper

```elixir
with_stdout_redirect(stdout_redirect, fn ->
  run_command(command, input, stderr_redirect)
end)
```

`with_stdout_redirect/2` is a helper that swaps the calling process's group
leader to a file-IO server for the duration of the callback. When
`run_command` writes to stdout (via `IO.write`), the data flows to the file
instead of the terminal.

If `stdout_redirect == nil`, `with_stdout_redirect/2` just calls the function
directly (no swap).

See [LEARNING.md §7](../LEARNING.md#7-group-leaders-and-io-redirection) for
how group leaders make this work.

## Why stdout and stderr are handled differently

| Stream | Mechanism | Where applied |
| --- | --- | --- |
| stdout | Group leader swap (Elixir-level) | `with_stdout_redirect/2` wrapping the command |
| stderr | Shell `2> file` syntax (OS-level) | `Execute` builds `sh -c "cmd 2> file"` |

The stdout mechanism works for both built-ins and external programs because
they both call `IO.write` (and external programs' output is forwarded through
`IO.write` in `Execute.loop/1`). The stderr mechanism only works for external
programs, which is a known limitation here — a built-in writing to
`:stderr` wouldn't be redirected. Fine for the current test suite.

## Flow example — `echo hi > out.log`

```
input = ["hi", ">", "out.log"]
extract_stderr_redirect → input=["hi", ">", "out.log"], stderr_redirect=nil
extract_stdout_redirect → input=["hi"], stdout_redirect={"out.log", :write}
no stderr file to create
with_stdout_redirect({"out.log", :write}, fn ->
  run_command("echo", ["hi"], nil)
end)
  → group leader swapped to a file IO server for out.log
  → run_command runs; IO.write goes to out.log
  → group leader restored after run_command returns
```

## Related concepts

- [code/redirects.md](redirects.md) — `extract_stderr_redirect/1`,
  `extract_stdout_redirect/1`, `with_stdout_redirect/2`
- [code/run_command.md](run_command.md) — what runs inside the wrapper
- [LEARNING.md §7](../LEARNING.md#7-group-leaders-and-io-redirection) —
  group-leader-based redirection
