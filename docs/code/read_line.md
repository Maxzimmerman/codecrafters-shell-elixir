# `read_line/1` — the keystroke-by-keystroke input loop

`lib/main.ex:35-69`

```elixir
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
```

## What it does

The main input loop. Accumulates a line of input one byte at a time, reacts
to special keys (TAB, Backspace, Ctrl-C, Ctrl-D, Enter), and returns the
finished line when the user presses Enter.

`buf` is the line so far (an Elixir string / binary). The function is tail
recursive — each iteration calls itself with an updated `buf`.

## The branch table

| Byte (decimal) | Source | Action |
| --- | --- | --- |
| `:eof` | stdin closed | return `buf` (or `:eof` if empty) |
| `?\r` (13) | Enter key | end of line; write newline; return `buf` |
| `?\n` (10) | piped input / alt Enter | same as `\r` |
| `?\t` (9) | Tab key | call `handle_tab`, continue |
| `127` | Backspace (modern) | erase one char, continue |
| `8` | Ctrl-H / old Backspace | same as 127 |
| `3` | Ctrl-C | print `^C`, exit with status 130 |
| `4` | Ctrl-D | EOF only if `buf` is empty (matches bash) |
| anything else | regular byte | echo it; append; continue |

## Why `\r` and `\n` are both handled

In raw mode, the Enter key produces `\r` (carriage return), not `\n`. The
kernel's `icrnl` translation that normally converts `\r` to `\n` happens as
part of canonical mode behavior — we turned that off when we set `-icanon`.

But piped input still uses `\n` (file line endings). Handling both means our
shell works whether stdin is a real tty or a pipe.

Both branches write `\r\n` to the screen so the cursor moves to the start of
the next line. Writing just `\n` would advance the row but leave the cursor
in the same column, creating a staircase. See
[LEARNING.md §5](../LEARNING.md#enter-is-also-tricky).

## Why `127` and `8` are both handled

| Byte | When it's sent |
| --- | --- |
| 127 (DEL) | Most modern terminals send this when you press Backspace |
| 8 (BS) | Older terminals; also Ctrl-H |

Different systems map the Backspace key differently. Handling both is
defensive but cheap.

## The Ctrl-D rule (`4`)

```elixir
4 ->
  if buf == "", do: :eof, else: read_line(buf)
```

This matches bash: Ctrl-D only causes EOF when the input buffer is empty.
If the user typed something and then hit Ctrl-D, bash ignores it. We do the
same.

(Note: in canonical mode the kernel handles this for you. In raw mode we get
the raw byte 4 and have to implement the rule ourselves.)

## The default branch — regular characters

```elixir
b when is_integer(b) ->
  char = <<b>>
  IO.write(char)
  read_line(buf <> char)
```

Three steps:

1. **Wrap to binary** — `<<b>>` builds a 1-byte binary from the integer.
   `IO.write` wants a binary, not a raw integer.
2. **Echo** — write the character to the screen. The kernel won't because
   we set `-echo`. Without this, the user would see nothing as they type.
3. **Append and recurse** — `buf <> char` builds a new string with the
   character on the end. Call ourselves.

Tail recursion in Elixir is optimized to a jump, so this doesn't grow the
stack even on long input.

## Flow example

User types `ec`, Backspace, `ho`:

```
read_line("")
  'e' (101)    → IO.write("e"); recurse with "e"
read_line("e")
  'c' (99)     → IO.write("c"); recurse with "ec"
read_line("ec")
  Backspace    → backspace("ec") writes "\b \b", returns "e"; recurse with "e"
read_line("e")
  'h' (104)    → IO.write("h"); recurse with "eh"
read_line("eh")
  'o' (111)    → IO.write("o"); recurse with "eho"
read_line("eho")
  Enter (13)   → IO.write("\r\n"); return "eho"
```

The terminal shows `eho` (the user can't tell that they typed `ec` first).
We return the buffer `"eho"` to `listen/0`.

## Related concepts

- [LEARNING.md §5](../LEARNING.md#5-manual-echo-and-line-editing) — why we
  echo, why `\r\n`
- [LEARNING.md §6](../LEARNING.md#6-control-characters) — what these byte
  values mean
- [code/backspace.md](backspace.md) — the erase mechanic
- [code/handle_tab.md](handle_tab.md) — what happens on TAB
