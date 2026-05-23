# `read_byte/0` — reading one byte from the tty

`lib/main.ex:27-33`

```elixir
defp read_byte do
  case :io.get_chars(:standard_io, ~c"", 1) do
    <<b>> -> b
    :eof -> :eof
    {:error, _} -> :eof
  end
end
```

## What it does

Read exactly one byte from stdin, return it as an integer. On EOF or error,
return the atom `:eof`.

## Argument-by-argument

`:io.get_chars(device, prompt, count)`:

- **`:standard_io`** — the name of the IO server for stdin/stdout.
- **`~c""`** — the prompt to print before reading. A charlist (list of
  integers). Empty here because we print the prompt ourselves in `listen/0`.
- **`1`** — how many characters to read.

## Three possible return values

| Return | Meaning |
| --- | --- |
| `<<b>>` (1-byte binary) | Successfully read one byte; `b` is its integer value |
| `:eof` | Stream closed (Ctrl-D in raw mode, or pipe closed) |
| `{:error, reason}` | Some I/O error; treated as EOF here |

The match `<<b>> -> b` is binary pattern matching — see
[LEARNING.md §2](../LEARNING.md#2-elixir-binary-syntax--b-and-friends).
`<<104>>` becomes `b = 104`.

## Why it returns immediately on a single keystroke

This isn't because of how we wrote `read_byte`. It's because:

1. The wrapper script ran `stty -icanon -echo min 1`. The kernel tty driver is
   in raw mode with `min 1`, so a single keystroke is enough to satisfy a
   `read()`.
2. We ask the IO server for exactly 1 character.
3. The IO server calls `read(0, buf, 1)` against fd 0.
4. The kernel returns as soon as 1 byte arrives.

If the tty were in canonical mode, this same code would block until the user
pressed Enter, then return only the first byte of the line and leave the rest
buffered for the next read.

## Why we convert binary -> integer

We work in integers from this point on because:

- It's simpler to compare against character codes: `?\r`, `?\t`, `127`.
- Guard clauses (`when c in [...]`) need integers.

`read_line/1` later wraps the integer back into `<<b>>` to call `IO.write`.

## Related concepts

- [LEARNING.md §4](../LEARNING.md#4-byte-at-a-time-io) — Erlang's IO server,
  underlying `read()` syscall
- [LEARNING.md §2](../LEARNING.md#2-elixir-binary-syntax--b-and-friends) —
  `<<b>>` pattern matching
- [LEARNING.md §1](../LEARNING.md#fd--file-descriptor) — file descriptors
