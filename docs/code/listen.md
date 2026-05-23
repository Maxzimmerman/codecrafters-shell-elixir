# `listen/0` and `process_line/1` — the REPL loop

`lib/main.ex:91-112`

```elixir
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
```

## What `listen/0` does

The Read-Eval-Print Loop. Forever (until EOF):

1. Print the prompt `$ `.
2. Read a line from the user.
3. Process it.
4. Loop.

The recursion is **tail-recursive** — `listen()` is the very last expression
in its branch — so the Elixir/Erlang compiler turns it into a jump. The
stack doesn't grow. This shell can run indefinitely without overflowing.

## EOF handling

```elixir
case read_line("") do
  :eof -> :ok
  input -> ...
end
```

`read_line` returns `:eof` when stdin is closed (Ctrl-D on empty line, or a
pipe that ran out). We return `:ok` from `listen/0`, which propagates back to
`main/1`, which returns to the escript runtime, which exits the process
cleanly.

## What `process_line/1` does

Takes the raw input string, tokenizes it (handling quotes/escapes), then
either ignores empty input or dispatches the command.

```elixir
case decode_console_input(input) do
  [] -> :ok                                    # blank line; reprompt
  [command | input] -> dispatch(command, input)
end
```

If the user typed `   ` (only whitespace) or just hit Enter, `tokenize/5`
returns `[]` and we skip dispatch. The next iteration of `listen/0` prints
the prompt again.

If they typed `echo hello`, tokenize returns `["echo", "hello"]`. We split
into `command = "echo"`, `input = ["hello"]`, and call `dispatch/2`.

## Why the prompt is written here, not in `read_line`

`read_line/1` doesn't know about the prompt — it just reads from where the
cursor is. The prompt is a `listen/0` concern: it's part of the REPL outer
loop, not the input-collection logic. Keeping them separate means
`read_line/1` could in principle be reused for sub-prompts later (e.g.
multiline input, `read` builtin) without entangling them.

## Flow example

User types `echo hi` and presses Enter:

```
listen()
  IO.write("$ ")           → terminal: "$ "
  read_line("")            → blocks, then returns "echo hi"
  process_line("echo hi")
    decode_console_input("echo hi") → ["echo", "hi"]
    dispatch("echo", ["hi"])
  listen()                 ← tail call back to the top
```

User presses Ctrl-D on empty line:

```
listen()
  IO.write("$ ")
  read_line("")            → returns :eof
  return :ok               ← back to main/1, escript exits
```

## Related concepts

- [code/read_line.md](read_line.md) — how the line is collected
- [code/dispatch.md](dispatch.md) — what happens after tokenization
- [code/tokenize.md](tokenize.md) — `decode_console_input/1` and `tokenize/5`
