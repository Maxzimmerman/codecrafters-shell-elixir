# `tokenize/5` — the quoting/escaping state machine

`lib/main.ex:195-244`

## What it does

Takes a raw input line like `echo "hello world" > out.txt` and produces a
list of tokens: `["echo", "hello world", ">", "out.txt"]`.

This isn't `String.split` — the meaning of each character depends on what
kind of quote we're inside. So we use a small state machine, one Elixir
function clause per transition.

## The entry point

```elixir
defp decode_console_input(input) do
  input
  |> String.trim_trailing("\n")
  |> tokenize([], "", :none, false)
end
```

Strip the trailing newline (if any), then call `tokenize/5` with initial
state.

## The arguments

```
tokenize(remaining_input, tokens_so_far_reversed, current_token, mode, has_token?)
```

| Arg | Meaning |
| --- | --- |
| `remaining_input` | The binary still to parse |
| `tokens_so_far_reversed` | Completed tokens, in reverse order |
| `current_token` | The token currently being built |
| `mode` | `:none`, `:single`, or `:double` — quoting context |
| `has_token?` | Whether `current_token` is a real token yet (needed for empty `""`) |

### Why "reversed"

Building a list by prepending (`[item | list]`) is O(1). Appending to the end
(`list ++ [item]`) is O(n). So we prepend during the parse, then reverse
once at the end. Total work: O(n) instead of O(n²).

### Why `has_token?`

Consider input `""` (a literal empty double-quoted string). It should produce
one empty token, not zero tokens. After we enter `:double`, see `"`, and exit
`:double`, `current_token` is still `""`. Without a flag we couldn't tell
"between tokens" apart from "have an empty token started." The flag
distinguishes the two cases.

## The termination clauses

```elixir
defp tokenize("", tokens, "", :none, false), do: Enum.reverse(tokens)
defp tokenize("", tokens, current, :none, true), do: Enum.reverse([current | tokens])
```

Two ways to end:

1. Input empty, current token empty, no token in progress → just reverse the
   accumulated list.
2. Input empty, but we have an in-progress token → push it first, then
   reverse.

Note: these only match when `mode == :none`. If the input ends inside an
open quote, neither clause matches and the function crashes. That's a known
shortcoming for malformed input but isn't tested against in this challenge.

## The transition clauses

Reading these as rows of a transition table:

### Entering quotes

```elixir
defp tokenize(<<"'", rest::binary>>, tokens, current, :none, _) do
  tokenize(rest, tokens, current, :single, true)
end

defp tokenize(<<"\"", rest::binary>>, tokens, current, :none, _) do
  tokenize(rest, tokens, current, :double, true)
end
```

In `:none`, a `'` enters single-quote mode and a `"` enters double-quote
mode. `has_token?` becomes true even if nothing's been added yet — that's
how empty quotes become empty tokens.

### Exiting quotes

```elixir
defp tokenize(<<"'", rest::binary>>, tokens, current, :single, has_token) do
  tokenize(rest, tokens, current, :none, has_token)
end

defp tokenize(<<"\"", rest::binary>>, tokens, current, :double, has_token) do
  tokenize(rest, tokens, current, :none, has_token)
end
```

A `'` inside `:single` exits back to `:none`. Same for `"` inside `:double`.

### Backslash inside double quotes

```elixir
defp tokenize(<<"\\", c::utf8, rest::binary>>, tokens, current, :double, _)
     when c in [?$, ?`, ?", ?\\] do
  tokenize(rest, tokens, current <> <<c::utf8>>, :double, true)
end
```

Inside `"..."`, backslash only escapes a specific set: `$`, `` ` ``, `"`, `\`.
Other backslashes are kept literally — but that's handled by the next, more
general "any char inside a quote" clause.

This matches POSIX shell behavior: `"\n"` becomes `\n` (a backslash followed
by n), not a newline. Only `\$`, `\``, `\"`, `\\` are special inside double
quotes.

### Any character inside a quote

```elixir
defp tokenize(<<c::utf8, rest::binary>>, tokens, current, mode, _)
     when mode in [:single, :double] do
  tokenize(rest, tokens, current <> <<c::utf8>>, mode, true)
end
```

If we're inside either quote and the previous clauses didn't match, append
the character literally.

### Backslash outside quotes

```elixir
defp tokenize(<<"\\", c::utf8, rest::binary>>, tokens, current, :none, _) do
  tokenize(rest, tokens, current <> <<c::utf8>>, :none, true)
end
```

In `:none`, a backslash escapes any following character: append the
following character literally and skip both.

### Whitespace outside quotes

```elixir
defp tokenize(<<c, rest::binary>>, tokens, current, :none, has_token)
     when c in [?\s, ?\t] do
  if has_token do
    tokenize(rest, [current | tokens], "", :none, false)
  else
    tokenize(rest, tokens, current, :none, false)
  end
end
```

Outside quotes, space or tab ends the current token (if any). The token is
pushed onto `tokens`, `current` resets to `""`, and `has_token?` becomes
false.

If there's no token in progress (`has_token == false`), the whitespace is
just consumed without producing anything.

### Any other character outside quotes

```elixir
defp tokenize(<<c::utf8, rest::binary>>, tokens, current, :none, _) do
  tokenize(rest, tokens, current <> <<c::utf8>>, :none, true)
end
```

The catch-all in `:none`: append the character to the current token, mark a
token as in-progress.

## Why function clauses instead of a `case`

Each clause pattern-matches both the input shape AND the state (`mode`). The
Elixir compiler picks the right clause by checking patterns top-to-bottom.
This is denser and clearer than a giant `case` with nested matches.

Order matters: more specific patterns must come before more general ones.
For example, the "backslash inside double quotes for special chars" clause
must come before the "any character inside a quote" clause, or the latter
would swallow the backslash first.

## Walkthrough — `echo "hi there" > out.log`

```
Input: `echo "hi there" > out.log`
State: ([], "", :none, false)

'e' → ([], "e", :none, true)
'c' → ([], "ec", :none, true)
'h' → ([], "ech", :none, true)
'o' → ([], "echo", :none, true)
' ' → push "echo": (["echo"], "", :none, false)
'"' → enter :double: (["echo"], "", :double, true)
'h' → (["echo"], "h", :double, true)
'i' → (["echo"], "hi", :double, true)
' ' → literal in :double: (["echo"], "hi ", :double, true)
't' → (["echo"], "hi t", :double, true)
'h' → (["echo"], "hi th", :double, true)
'e' → (["echo"], "hi the", :double, true)
'r' → (["echo"], "hi ther", :double, true)
'e' → (["echo"], "hi there", :double, true)
'"' → exit :double: (["echo"], "hi there", :none, true)
' ' → push "hi there": (["hi there", "echo"], "", :none, false)
'>' → (["hi there", "echo"], ">", :none, true)
' ' → push ">": ([">", "hi there", "echo"], "", :none, false)
'o' → ([">", "hi there", "echo"], "o", :none, true)
'u' → ([">", "hi there", "echo"], "ou", :none, true)
't' → ([">", "hi there", "echo"], "out", :none, true)
'.' → ([">", "hi there", "echo"], "out.", :none, true)
'l' → ([">", "hi there", "echo"], "out.l", :none, true)
'o' → ([">", "hi there", "echo"], "out.lo", :none, true)
'g' → ([">", "hi there", "echo"], "out.log", :none, true)
EOF, has_token=true → reverse(["out.log" | tokens])
   = ["echo", "hi there", ">", "out.log"]
```

Note `>` is just a token to the tokenizer — it doesn't know it's a redirect
operator. That's `extract_stdout_redirect/1`'s job to recognize, downstream.
Separation of concerns: tokenize what's there; interpret it elsewhere.

## Walkthrough — `echo ''` (empty single-quoted string)

```
'e','c','h','o' → ([], "echo", :none, true)
' ' → push "echo": (["echo"], "", :none, false)
"'" → enter :single: (["echo"], "", :single, true)
"'" → exit :single: (["echo"], "", :none, true)
EOF, has_token=true → reverse(["" | ["echo"]]) = ["echo", ""]
```

Without `has_token?`, we'd lose the empty token. With it, we correctly
produce `["echo", ""]`.

## Related concepts

- [LEARNING.md §9](../LEARNING.md#9-hand-rolled-tokenizer-state-machines) —
  state machines in general
- [code/listen.md](listen.md) — caller (`decode_console_input/1`)
- [code/redirects.md](redirects.md) — what interprets `>`, `>>`, etc. after
  tokenization
