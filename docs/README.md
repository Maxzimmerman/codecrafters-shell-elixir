# Shell Project Documentation

Documentation for the codecrafters-shell-elixir project, organized in two parts:

## Concepts — `LEARNING.md`

[LEARNING.md](LEARNING.md) is a self-contained tour of the systems-programming
concepts this project touches. Read this first if you're new to terminal I/O,
file descriptors, Erlang's IO model, or shell tokenization.

Topics covered:

1. Vocabulary: pty, buf, fd
2. Elixir binary syntax (`<<b>>` and friends)
3. The kernel/tty layer (canonical vs raw mode, stty)
4. Byte-at-a-time I/O
5. Manual echo and line editing
6. Control characters
7. Group leader and I/O redirection
8. Ports (subprocess execution)
9. Hand-rolled tokenizer (state machines)

## Per-code-piece docs — `code/`

Each file in `code/` explains one chunk of `lib/main.ex` in detail: what it
does, the key code, why it's written that way, and edge cases.

| File | Function(s) | Purpose |
| --- | --- | --- |
| [code/main.md](code/main.md) | `main/1` | Entry point and IO setup |
| [code/read_byte.md](code/read_byte.md) | `read_byte/0` | Reading one byte from the tty |
| [code/read_line.md](code/read_line.md) | `read_line/1` | The keystroke-by-keystroke input loop |
| [code/backspace.md](code/backspace.md) | `backspace/1` | Erasing a character visually |
| [code/handle_tab.md](code/handle_tab.md) | `handle_tab/1` | Tab completion logic |
| [code/listen.md](code/listen.md) | `listen/0`, `process_line/1` | The REPL loop |
| [code/dispatch.md](code/dispatch.md) | `dispatch/2` | Coordinating redirects and execution |
| [code/run_command.md](code/run_command.md) | `run_command/3` | External program vs built-in dispatch |
| [code/redirects.md](code/redirects.md) | `extract_*_redirect`, `with_stdout_redirect` | Redirect parsing and group-leader swap |
| [code/tokenize.md](code/tokenize.md) | `tokenize/5` | Quoting/escaping state machine |

## Reading order

If you're learning from scratch:

1. Read [LEARNING.md](LEARNING.md) sections 1–2 (vocabulary, binary syntax).
2. Read [code/main.md](code/main.md) and [code/listen.md](code/listen.md) to see
   the program's skeleton.
3. Read [LEARNING.md](LEARNING.md) sections 3–5 (tty, byte I/O, echo) alongside
   [code/read_byte.md](code/read_byte.md), [code/read_line.md](code/read_line.md),
   [code/backspace.md](code/backspace.md), and [code/handle_tab.md](code/handle_tab.md).
4. Read [LEARNING.md](LEARNING.md) sections 7–8 (group leader, ports) alongside
   [code/dispatch.md](code/dispatch.md), [code/run_command.md](code/run_command.md),
   and [code/redirects.md](code/redirects.md).
5. Read [LEARNING.md](LEARNING.md) section 9 (state machines) alongside
   [code/tokenize.md](code/tokenize.md).
