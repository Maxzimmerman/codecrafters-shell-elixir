# `handle_tab/1` — tab completion logic

`lib/main.ex:78-89`

```elixir
@builtins ~w(echo exit)

defp handle_tab(buf) do
  case Enum.filter(@builtins, &String.starts_with?(&1, buf)) do
    [match] when buf != "" ->
      suffix = String.replace_prefix(match <> " ", buf, "")
      IO.write(suffix)
      match <> " "

    _ ->
      IO.puts("\x07")
      buf
  end
end
```

## What it does

The user pressed TAB. Look at what they've typed so far (`buf`). If exactly
one built-in starts with that prefix, complete it (write the rest of the word
plus a trailing space to the terminal, and return the completed buffer).
Otherwise beep and return the buffer unchanged.

## Step by step with `buf = "ech"`

1. **Filter the builtins by prefix.**
   `Enum.filter(["echo", "exit"], &String.starts_with?(&1, "ech"))` returns
   `["echo"]`.

2. **Pattern match `[match]`.**
   Exactly one result. `match = "echo"`. Guard `buf != ""` holds.

3. **Compute the suffix to write.**
   We want the terminal to end up showing `echo `. The user already typed
   `ech` so the terminal already shows `ech`. We only need to write what's
   missing.
   `match <> " "` = `"echo "`.
   `String.replace_prefix("echo ", "ech", "")` = `"o "`.

4. **Write the suffix.** `IO.write("o ")` — terminal now shows `echo `.

5. **Return the new buffer.** Return `match <> " "` = `"echo "` so
   `read_line` keeps reading with the right state.

## The other branches

The fallback `_ ->` covers three cases:

| Filter result | Why | Effect |
| --- | --- | --- |
| `[]` | no builtin starts with `buf` | beep, no change |
| `[a, b, ...]` | multiple matches (e.g. `buf = "e"` matches both `echo` and `exit`) | beep, no change |
| `[match]` but guard fails | `buf` is empty (just hit TAB at the prompt) | beep, no change |

`IO.puts("\x07")` writes the BEL control character — most terminals respond
with an audible beep or a brief visual flash. That signals "I heard your TAB
but I can't complete."

## Why the guard `when buf != ""`

If `buf` is empty, every builtin satisfies `String.starts_with?(&1, "")` —
they all start with the empty string. The filter would return both `echo`
and `exit`, which doesn't match `[match]` anyway. But to be defensive (in
case the builtin list ever had only one entry), the guard explicitly rejects
the empty-buf case.

## Important limitation — whole-buffer matching

`handle_tab/1` matches `buf` against the entire builtin name, not just the
last word. So:

- `ech<TAB>` works.
- `echo ec<TAB>` does NOT complete `ec` to `echo` (the buffer is `"echo ec"`,
  which starts with no builtin).

This is fine for the current stage (the tester only sends `ech<TAB>` and
`exi<TAB>`). Later stages will need word-aware completion that looks at the
last whitespace-delimited token.

## Where the prompt update appears on screen

The completion suffix is written **mid-line**, while we're still inside
`read_line/1`. The user sees:

```
$ ech         ← before TAB
$ echo        ← after TAB (the "o " was just written)
```

`handle_tab` returns `"echo "` and `read_line/1` continues reading. The next
key the user presses will be appended after the space.

## Related concepts

- [LEARNING.md §6](../LEARNING.md#6-control-characters) — TAB is ASCII byte 9
- [code/read_line.md](read_line.md) — where `handle_tab` is called
