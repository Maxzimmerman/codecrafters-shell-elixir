# External resources

Video tutorials and references that pair with [LEARNING.md](LEARNING.md).
Organized by topic, with a note on which LEARNING section each maps to.

## TTY and pseudo-terminals (LEARNING §1, §3)

- [What's a TTY? (And Why Linux Still Thinks It's 1970)](https://www.youtube.com/watch?v=J7utkbl0mWw)
  — Best starting point. Explains the 1970s teletype history and why Unix
  still uses tty terminology.
- [Explaining terminals - SSH, TTY, PTY, etc.](https://www.youtube.com/watch?v=ix4ajQgLQOU)
  — Longer, thorough taxonomy of all the terminal-related terms.
- [I Never Thought This Was Possible… in a Linux Terminal](https://www.youtube.com/watch?v=LlDNTyCVRnE)
  — PTY internals, `/dev/pts`, `ptmx` device.

## File descriptors, stdin/stdout/stderr (LEARNING §1)

- [Linux Standard Streams Explained: stdin, stdout, & stderr for Beginners](https://www.youtube.com/watch?v=9FuWfNdOnsY)
  — Clear beginner intro to the three standard streams.
- [File Descriptor concept dumbed down with simple example](https://www.youtube.com/watch?v=qHE4RdSZdiE)
  — What fd integers actually are.

## Raw mode / termios (LEARNING §3, §5)

Most directly relevant to this project — these tutorials do in C exactly
what we did in Elixir.

- [Text editor from the ground up, part 2: terminal raw mode](https://www.youtube.com/watch?v=B5TYOvbQW8o)
  — The "kilo" editor tutorial. Walks through `stty`/`termios`, disabling
  echo, byte-by-byte input. Highest signal-to-noise for understanding our
  `read_line/1`.
- [Build An Editor In Go - Part 1: Terminal Raw Mode](https://www.youtube.com/watch?v=UeV6WG2l31I)
  — Same concepts in Go.
- [Linux Terminal Game from Scratch I - Termios, ANSI Escape Codes](https://www.youtube.com/watch?v=WvSOSyi5lWY)
  — Termios plus ANSI escape codes for colors and cursor moves.

## Building a shell — project context

- [Let's Write a Simple Shell in C!](https://www.youtube.com/watch?v=YMEHrXSsdo0)
  — Fork/exec/wait fundamentals. The C analog of what `Execute` does via
  Erlang Ports.
- [Let's build a super simple shell in C](https://www.youtube.com/watch?v=yTR00r8vBH8)
  — Alternative walk-through with GitHub code.
- [OMG building a shell in 10 minutes (Stefanie Schirmer, EnthusiastiCon)](https://www.youtube.com/watch?v=k6TTj4C0LF0)
  — Fast conference talk; good high-level overview.

## Elixir binaries and pattern matching (LEARNING §2)

- [Binaries, strings, and charlists | Elixir Getting Started Guide](https://www.youtube.com/watch?v=MW0NackFNX8)
  — Directly about `<<...>>` syntax and the binary/charlist distinction.
- [Pattern Matching | Elixir Getting Started Guide](https://www.youtube.com/watch?v=_uKorrkyWPM)
  — The `=` operator as a match, not assignment.

## Erlang processes and message passing (LEARNING §7, §8 background)

- [ElixirZone: Erlang 101 - Processes & Parallelization](https://www.youtube.com/watch?v=EZY9W-3D5qY)
  — The process model that Ports and IO servers are built on.
- [How Does Erlang & Elixir Pass messages between processes](https://www.youtube.com/watch?v=NZkct6DLItI)
  — Message passing under the hood.

## Topics without great YouTube coverage

Two LEARNING.md topics don't have good videos available. Use the official
docs instead.

### Erlang group leaders / IO server protocol (LEARNING §7)

- [Erlang `io` module docs](https://www.erlang.org/doc/man/io.html) — the
  protocol that `IO.write` uses under the hood.
- Saša Jurić's *Elixir in Action*, chapter on processes — clearest book
  treatment of the group leader concept.

### Erlang Ports (LEARNING §8)

- [Erlang Ports tutorial](https://www.erlang.org/doc/tutorial/c_port.html)
  — Official tutorial. More useful than any YouTube video.
- [Elixir `Port` module docs](https://hexdocs.pm/elixir/Port.html) — what
  `Port.open` accepts and what messages it sends back.

## Suggested viewing order

If you have time for just one video, pick
[Text editor from the ground up, part 2: terminal raw mode](https://www.youtube.com/watch?v=B5TYOvbQW8o).
Every concept it covers appears in our `read_line/1`.

For a longer learning path:

1. [What's a TTY?](https://www.youtube.com/watch?v=J7utkbl0mWw) — vocabulary
2. [File Descriptor concept](https://www.youtube.com/watch?v=qHE4RdSZdiE) — fds
3. [Text editor from the ground up, part 2](https://www.youtube.com/watch?v=B5TYOvbQW8o) — the core of what we do
4. [Let's Write a Simple Shell in C!](https://www.youtube.com/watch?v=YMEHrXSsdo0) — broader shell context
5. [Binaries, strings, and charlists](https://www.youtube.com/watch?v=MW0NackFNX8) — Elixir-specific
6. [Erlang Ports tutorial](https://www.erlang.org/doc/tutorial/c_port.html) — read after watching the C shell video
