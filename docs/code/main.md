# `main/1` — entry point

`lib/main.ex:22-25`

```elixir
def main(_args) do
  :io.setopts(:standard_io, binary: true)
  listen()
end
```

## What it does

The escript entry point. `mix escript.build` produces a binary that calls
`CLI.main(args)` when run.

Two things happen:

1. **`:io.setopts(:standard_io, binary: true)`** — tells Erlang's IO server
   to deliver reads as **binaries** (e.g. `<<104>>`) rather than charlists
   (e.g. `~c"h"`). Without this, our pattern `<<b>>` in `read_byte/0` would
   fail to match.

2. **`listen()`** — start the REPL.

## What is NOT here

The actual raw tty mode is **not** set in Elixir. That's done in the wrapper
scripts (`your_program.sh` and `.codecrafters/run.sh`) before exec'ing the
escript:

```sh
stty -icanon -echo min 1 2>/dev/null || true
exec /tmp/codecrafters-build-shell-elixir "$@"
```

Why? Because `stty` needs to talk to the controlling tty. If we tried
`:os.cmd("stty …")` from inside the escript, Erlang would spawn a child shell
with pipes for stdio — not the tty — and `stty` would have nothing to
configure. Doing it in the wrapper means the escript inherits a tty that's
already in raw mode.

The `|| true` makes the wrapper safe when stdin isn't a tty (piped input):
`stty` fails silently and the program still works for non-interactive tests.

## Related concepts

- [LEARNING.md §3](../LEARNING.md#3-the-kernel--tty-layer) — canonical vs raw
  mode, stty
- [LEARNING.md §4](../LEARNING.md#4-byte-at-a-time-io) — Erlang's IO server
  model
- [LEARNING.md §2](../LEARNING.md#2-elixir-binary-syntax--b-and-friends) — why
  `binary: true` matters
