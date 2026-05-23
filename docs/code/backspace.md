# `backspace/1` — erasing a character visually

`lib/main.ex:71-76`

```elixir
defp backspace(""), do: ""

defp backspace(buf) do
  IO.write("\b \b")
  String.slice(buf, 0..-2//1)
end
```

## What it does

Visually erase the last character on the terminal **and** remove the last
character from our internal buffer. Returns the shortened buffer.

If the buffer is empty, do nothing — you can't erase past the prompt.

## The `"\b \b"` trick

Backspace is two separate problems: the cursor needs to move back, and the
character on screen needs to disappear. We can't "delete" a character — we
can only overwrite it. So:

| byte | effect |
| --- | --- |
| `\b` (0x08) | move cursor one column LEFT |
| ` ` (0x20) | write a space at the cursor; cursor moves RIGHT |
| `\b` (0x08) | move cursor one column LEFT again |

Net effect: the character previously at the cursor position is overwritten by
a space, and the cursor ends up on top of it. Visually, the character has
disappeared.

This is the classic terminal idiom — every interactive Unix program that
implements its own line editing uses some version of it.

## `String.slice(buf, 0..-2//1)`

This drops the last character of `buf`.

- `0..-2` — Elixir range from index 0 to index -2 (the second-to-last
  character). Inclusive on both ends.
- `//1` — the explicit step. Elixir 1.16+ requires you to spell out the step
  when using negative ranges to disambiguate intent.

So `String.slice("ech", 0..-2//1)` returns `"ec"`.

## Why we need a guard for empty buffers

```elixir
defp backspace(""), do: ""
```

If `buf` is empty and we tried `String.slice("", 0..-2//1)` we'd get an empty
string back anyway, but we'd also have written `"\b \b"` to the terminal —
which would move the cursor LEFT past the `$ ` prompt. We don't want to
overwrite the prompt.

The first clause short-circuits: empty buffer → no IO, just return `""`.

## Flow example

State: `buf = "ec"`, terminal shows `$ ec`, cursor at column 4.

```
backspace("ec"):
  IO.write("\b")   → cursor moves to column 3 (now on 'c')
  IO.write(" ")    → writes space over 'c'; cursor at column 4
  IO.write("\b")   → cursor moves to column 3
  String.slice("ec", 0..-2//1) → "e"
  returns "e"
```

Terminal now shows `$ e`, cursor at column 3. The internal buffer is `"e"`.
Identical to what the user would see in canonical mode after pressing
Backspace — except we did it manually.

## Limitations

- **Doesn't handle multi-byte characters.** `String.slice/3` is grapheme-aware
  in Elixir, so it'd correctly drop a full grapheme from the buffer, but on
  screen `"\b \b"` only moves the cursor one column. A multi-byte character
  (e.g. an emoji that takes two columns to render) wouldn't be fully erased
  visually. Fine for ASCII input.
- **Doesn't handle backspace at end of a wrapped line.** Some terminals don't
  let `\b` cross a line boundary. Fine for short shell prompts.

## Related concepts

- [LEARNING.md §5](../LEARNING.md#backspace-is-the-tricky-one) — the `\b \b`
  dance and why we need it
- [code/read_line.md](read_line.md) — where `backspace/1` is called
