# Learning notes — systems concepts behind this shell

A self-contained tour of the systems-programming ideas that show up in this
project. Each section explains a concept from the ground up, then ties it back
to where it appears in `lib/main.ex` (or the wrapper scripts).

---

## 1. Vocabulary: pty, buf, fd

### pty — pseudo-terminal

**TTY** is short for "teletype" — those old printer-with-keyboard machines from
the 1960s that connected to mainframes over serial cables. The name stuck
around in Unix because the kernel's terminal-handling subsystem is called the
"tty subsystem."

A **pseudo-terminal (pty)** is a software pair of file descriptors that
pretends to be a real serial-cable terminal. There are two ends:

```
┌──────────────────┐       ┌──────────────────┐
│ Terminal.app     │       │ your shell       │
│ (the "master")   │ ◄───► │ (the "slave")    │
│                  │  pty  │                  │
│ - reads keyboard │       │ - reads stdin    │
│ - draws to GUI   │       │ - writes stdout  │
└──────────────────┘       └──────────────────┘
```

- The **master** side is held by Terminal.app (or iTerm, VS Code's terminal,
  `expect`, the codecrafters tester, etc.). Whatever the master writes, the
  slave reads as stdin. Whatever the slave writes as stdout, the master
  receives and displays.
- The **slave** side looks exactly like a regular tty to our shell. Our shell
  can't tell whether it's talking to a real RS-232 cable or to Terminal.app.

In between sits the kernel's **tty driver** — the part of the kernel
implementing canonical mode, echo, signal generation, etc. That's the thing
`stty` configures.

Run `tty` in your terminal to see the slave-side device name, like
`/dev/ttys003`.

### buf — buffer

Just a variable name. Short for "buffer," a generic CS term for **a chunk of
memory used to accumulate or hold data temporarily**.

In our `read_line/1`, `buf` is the string of characters typed so far on the
current line. When the user types `e`, `c`, `h`, the function calls itself
recursively with `buf = "e"`, then `"ec"`, then `"ech"`.

The word "buffer" appears in many contexts:

- A **kernel input buffer** holds keystrokes the user typed before any program
  has read them.
- A **stdio buffer** in C holds bytes that `printf` produced but hasn't flushed
  yet.
- An **HTTP response buffer** holds the body being built up before sending.

In all of these, "buffer" just means "a place to stash data while we're
working with it." `buf` is the conventional short name.

### fd — file descriptor

A **file descriptor** is a small non-negative integer that the kernel hands
you when you open something. You use that number to tell the kernel "act on
this thing."

In Unix, **everything is a file** — but "file" here doesn't mean "thing on
disk." It means "thing you can read from or write to":

| What it is | Has an fd? |
| --- | --- |
| A regular file on disk | yes |
| A directory | yes |
| A pipe between processes | yes |
| A network socket | yes |
| A terminal (tty/pty) | yes |
| `/dev/null` | yes |

When you call `open("/etc/passwd", O_RDONLY)`, the kernel does some
bookkeeping and returns an integer, say `5`. Now whenever you want to read
from that file, you say `read(5, ...)`. The number `5` is meaningless except
as a key into the kernel's table of "things this process has open."

#### The standard three

Every Unix process starts life with three fds already open:

| fd | name | usual destination |
| --- | --- | --- |
| 0 | stdin | the tty (keyboard input) |
| 1 | stdout | the tty (screen output) |
| 2 | stderr | the tty (error messages) |

When you run `cat file.txt > out.log` in bash:

1. Bash forks.
2. Before exec'ing `cat`, the child closes its fd 1 and reopens it pointing at
   `out.log`.
3. Bash exec's `cat`, which writes to fd 1 as normal — but fd 1 now points at
   `out.log`, not the terminal.

`cat` doesn't know its output got redirected. From its perspective, fd 1 is
just fd 1. That's the magic of fds: a small integer that means whatever the
kernel says it means right now.

---

## 2. Elixir binary syntax — `<<b>>` and friends

### Two meanings of "binary"

The word is overloaded:

1. **Binary number** (math/CS sense): a number written in base 2 using 0s and
   1s. `01101000` is a binary number; its decimal value is 104.
2. **Binary** (Elixir sense): a sequence of bytes — a chunk of raw data.
   `<<104>>` is *a binary* in this sense: it's a 1-byte data structure. The
   single byte inside it has the bit pattern `01101000`.

Two different concepts that share a name. The Elixir docs always mean #2.

### Binaries are byte sequences

```elixir
<<>>               # empty binary (0 bytes)
<<104>>            # binary with one byte: the value 104
<<104, 105>>       # binary with two bytes: 104, 105
"hi"               # exactly the same thing as <<104, 105>>
<<0b01101000>>     # binary, same one byte, written in base 2
<<0x68>>           # same byte, in hex
```

All of these are equivalent. The `<< ... >>` brackets say "I'm building a
binary." Inside, you list the bytes (as integers in any base, or as strings
which are themselves binaries).

Proof in `iex`:

```elixir
iex> <<104>> == "h"
true
iex> "hi" == <<104, 105>>
true
iex> <<0b01101000>> == "h"
true
```

### As a pattern (matching mode)

When `<<b>>` appears on the left side of `=`, it's a pattern: "the right side
must be a 1-byte binary; bind the integer value of that byte to `b`."

```elixir
iex> <<b>> = "h"
"h"
iex> b
104
```

In our code:

```elixir
case :io.get_chars(:standard_io, ~c"", 1) do
  <<b>> -> b
  ...
end
```

`:io.get_chars` returns `<<104>>` when the user types `h`. The pattern `<<b>>`
matches it and binds `b = 104`.

### As a constructor (building mode)

When `<<b>>` appears on the right side, it builds a 1-byte binary from an
integer:

```elixir
iex> b = 104
104
iex> <<b>>
"h"
```

In `read_line/1`:

```elixir
b when is_integer(b) ->
  char = <<b>>          # integer 104 -> binary "h"
  IO.write(char)
```

We have the integer (104) and need a binary for `IO.write`. `<<b>>` wraps it.

### What `<<b>>` actually does to the bits

In a sense, nothing. The 8 bits stay the same:

- The byte `01101000` is the integer `104`, is the character `h`, is the
  binary `<<104>>`, is the binary `"h"`. These are four ways of writing the
  same 8 bits.
- `<<b>>` is just the bridge between the "integer view" and the "binary view."

The pattern direction: "given a 1-byte binary, extract the integer view."
The constructor direction: "given an integer, give me the 1-byte binary view."

### Why two views?

Different Elixir functions want different types:

- Arithmetic and comparisons (`+`, `<`, guards like `when c in [?\s, ?\t]`)
  want **integers**.
- I/O (`IO.write`, `String.length`) wants **binaries**.

We unwrap to integers for branching on byte values (`?\r == 13`), and wrap
back to binaries when writing to the screen.

### Multi-byte and sub-byte forms

The same syntax handles bigger and smaller structures:

```elixir
iex> <<first, second, rest::binary>> = "hello"
iex> first
104    # 'h'
iex> second
101    # 'e'
iex> rest
"llo"

iex> <<a::4, b::4>> = <<104>>     # split one byte into two 4-bit halves
iex> a
6      # top 4 bits: 0110
iex> b
8      # bottom 4 bits: 1000
```

That `::4` size specifier is real bit-level work (the binary parser does the
bitwise math for you). We don't need it in this project — we work with whole
bytes only.

---

## 3. The kernel / tty layer

### What a "terminal" actually is

In the 1970s, a terminal was physical hardware connected by a serial cable
to a Unix server. You typed; bytes flowed over the wire to the OS; the OS sent
bytes back; the terminal displayed them.

Today there's no cable. When you open Terminal.app, that program emulates the
old hardware. To keep existing Unix programs working without modification, the
kernel pretends a terminal is still attached via a **pseudo-terminal** (pty —
see §1).

The kernel piece in the middle is called the **tty driver** (sometimes "line
discipline"). It sits between programs and the actual terminal. That driver is
what we configure with `stty`. It's a chunk of code in the kernel with knobs
you can turn.

### The two modes: canonical vs raw

The tty driver has dozens of settings, but the big one is **canonical mode**
(also called "cooked" mode). In canonical mode the driver does a lot for you:

| What it does | Why |
| --- | --- |
| Holds bytes in a buffer until Enter | Programs that want lines don't have to think |
| Handles Backspace by removing the previous byte | Programs never see the backspace |
| Echoes typed characters to the screen | The user sees what they're typing |
| Translates Ctrl-C into a SIGINT signal | Standard "kill this program" behavior |
| Translates Ctrl-D into EOF | Standard "end of input" |
| Translates `\r` (Enter) to `\n` for the program | So programs see `\n` line endings |

Wonderful if you're writing `cat` or `grep` — you just call `read()` and get a
complete line.

But if you're writing a shell that wants to react to a TAB keystroke,
canonical mode is a problem: the driver won't give you the TAB until the user
presses Enter, because it's waiting for a complete line.

So we turn it off:

```sh
stty -icanon -echo min 1
```

- `-icanon` — turn OFF canonical mode (the `i` is for "input")
- `-echo` — turn OFF the kernel's auto-echoing of typed characters
- `min 1` — in non-canonical mode, return as soon as 1 byte is available

Now the driver becomes a pass-through: every keystroke is delivered to our
program as it happens, with no buffering and no echoing. We're responsible
for everything.

### Why we do this in the wrapper script

`your_program.sh` and `.codecrafters/run.sh` run `stty` before exec'ing the
escript. We can't do it from Erlang's `:os.cmd` because that spawns the child
shell with **pipes** for stdio, not the tty — `stty` then can't find a
terminal to configure.

By configuring the tty in the wrapper and then `exec`'ing the escript, the
escript inherits the now-raw tty.

### See it for yourself

```sh
$ stty -icanon -echo min 1
$ cat                        # cat now reads byte-by-byte, with no echo
hi^[[A^Hi                    # arrow keys, backspace show up as raw bytes
^C
$ stty sane                  # reset
```

---

## 4. Byte-at-a-time I/O

### How `read()` actually works

At the OS level, reading is one syscall: `read(fd, buf, count)`. "From file
descriptor `fd`, fill `buf` with up to `count` bytes."

`read()` blocks until at least one byte is available (or EOF). What that means
depends on what `fd` is:

- **Regular file**: returns immediately with up to `count` bytes.
- **Pipe**: blocks until the other side writes something.
- **Tty in canonical mode**: blocks until Enter, then returns the whole line.
- **Tty in raw mode (`min 1`)**: blocks until 1 keystroke, returns 1 byte.

So one-byte-per-keystroke behavior comes from **the kernel mode** (set by
stty), not from how we call `read`. Our code just has to ask for 1 byte at a
time and trust each read corresponds to one keystroke.

### Elixir/Erlang on top of `read()`

Erlang doesn't expose `read()` directly. Instead it has an **IO server**
model:

```
your process   ─►   IO server process   ─►   underlying read() syscall
               ◄─                       ◄─
```

When you call `:io.get_chars(:standard_io, "", 1)`, you send a message to the
`:standard_io` IO server, asking it for 1 character from stdin. The IO server
calls `read()` under the hood and sends back the result.

The IO server can add features (encoding handling, expand-fun completion in
some configurations), but in our setup — with `binary: true` and no fancy
options — it's essentially a thin wrapper over `read(fd, buf, 1)`.

---

## 5. Manual echo and line editing

Once we asked the kernel to stop echoing (`-echo`), nothing the user types
appears on screen automatically. We have to do it ourselves.

### Why echo matters

```sh
$ stty -echo
$ echo hello
                # you type "echo hello" but see nothing
hello           # only this line appears, as program output
$ stty echo
```

The kernel still received your keystrokes. It just didn't show them. Programs
that read stdin still get them. But the user sees nothing — unusable.

### Doing it ourselves

In `read_line/1`:

```elixir
b when is_integer(b) ->
  char = <<b>>
  IO.write(char)         # put the typed character back on screen
  read_line(buf <> char)
```

We get the byte from the kernel and immediately write it back to stdout. We
look like canonical mode again, except we control exactly what gets echoed.

### Backspace is the tricky one

When the user presses Backspace, the byte that arrives is `127` (DEL on
macOS/Linux) or `8` (BS, older systems). The kernel doesn't erase anything
for us — we get the raw byte and do the visual erase ourselves:

```elixir
defp backspace(buf) do
  IO.write("\b \b")
  String.slice(buf, 0..-2//1)
end
```

That `"\b \b"` is a three-character magic dance:

| byte | effect |
| --- | --- |
| `\b` (0x08) | move cursor one column LEFT |
| ` ` (0x20) | write a space; cursor moves RIGHT |
| `\b` (0x08) | move cursor one column LEFT again |

Net effect: the character previously at the cursor is overwritten by a space,
and the cursor ends up on top of it. Visually, "the character disappeared."

We also slice it out of our internal buffer with `String.slice(buf, 0..-2//1)`.
The `//1` is the explicit step (required in Elixir 1.16+ for negative ranges).

### Enter is also tricky

In canonical mode the kernel translates `\r` (carriage return, what Enter
produces) into `\n` (newline). In raw mode it doesn't. So:

```elixir
?\r ->
  IO.write("\r\n")
  buf
```

We write `\r\n` ourselves: `\r` moves the cursor to column 0, `\n` moves down
one row. Together: "start a new line." If we wrote just `\n`, the cursor
would go down but stay in the same column — creating a staircase effect.

---

## 6. Control characters

### The ASCII table's first 32 entries

ASCII byte values 0–31 are **control characters** — not letters or
punctuation, but commands. Originally for mechanical printers and teletypes.
The ones that still matter today:

| dec | hex | name | sent by | meaning |
| --- | --- | --- | --- | --- |
| 3 | 0x03 | ETX | Ctrl-C | "interrupt" |
| 4 | 0x04 | EOT | Ctrl-D | "end of transmission" / EOF |
| 8 | 0x08 | BS | Ctrl-H / Backspace (old) | backspace |
| 9 | 0x09 | HT | Tab key | horizontal tab |
| 10 | 0x0A | LF | Ctrl-J | newline (`\n`) |
| 13 | 0x0D | CR | Enter key | carriage return (`\r`) |
| 27 | 0x1B | ESC | Esc key | start of escape sequence (arrow keys, etc.) |
| 127 | 0x7F | DEL | Backspace (modern) | delete |

The "Ctrl-X" naming convention is literal: hold Ctrl, press X, the terminal
sends `(X minus 64) AND 0x1F`. So `Ctrl-C = 3`, `Ctrl-D = 4`, `Ctrl-H = 8`,
`Ctrl-M = 13`.

### What the kernel normally does with them

In canonical mode the tty driver intercepts these:

- Ctrl-C → kernel sends `SIGINT` to the foreground process group → program
  exits.
- Ctrl-D → kernel returns a 0-byte read → program sees EOF.
- Ctrl-H / DEL → kernel deletes one byte from its input buffer.
- Enter (`\r`) → kernel ends the line, often translating to `\n`.

In raw mode (`-icanon`) the driver delivers them all as raw bytes. We
interpret them ourselves.

(Note: Ctrl-C is special — there's a separate setting `-isig` that controls
whether the driver still converts it to a signal. We left `isig` ON, so the
kernel would still send us SIGINT. But just in case, we also handle byte `3`
explicitly.)

### In our code

```elixir
?\r -> ...                  # Enter
?\n -> ...                  # alternate Enter / piped input
?\t -> ...                  # Tab — completion
127  -> backspace(...)      # modern Backspace
8    -> backspace(...)      # Ctrl-H / old Backspace
3    -> System.halt(130)    # Ctrl-C — exit code 130 is "killed by SIGINT"
4    -> :eof                # Ctrl-D — only EOF if buf is empty (bash behavior)
b when is_integer(b) -> ... # everything else: a printable character
```

`?\t == 9`, `?\r == 13`, `?\n == 10`. The `?` syntax is Elixir for "the
integer codepoint." `?\t` and `9` are the same value — `?\t` is just more
readable.

---

## 7. Group leaders and I/O redirection

### Erlang's I/O design

In most languages, "stdout" is a global thing — `printf` writes to fd 1,
period. In Erlang it's per-process and routed through a designated process
called the **group leader**.

Every Erlang process has a field `group_leader`. When you call `IO.write("hi")`:

1. Elixir looks up the current process's group leader.
2. Sends it a message:
   `{:io_request, from, ref, {:put_chars, :unicode, "hi"}}`.
3. The group leader (an IO server process) handles the message — writes to
   its underlying destination.

```
your process                group leader process
  │                            │
  │── IO.write("hi") ─────────►│
  │                            │── write(fd=1, "hi") ──► terminal
  │◄──── ok ───────────────────│
```

`IO.write` doesn't directly talk to fd 1. It talks to whatever process is the
group leader. That indirection is the leverage point for redirection.

### The redirect trick

`File.open("out.log", [:write])` doesn't just return a raw file handle — it
returns a PID of a new IO server process that writes to that file. That PID
can act as a group leader.

So in `with_stdout_redirect`:

```elixir
{:ok, file} = File.open(path, [mode])           # spawns IO server for "out.log"
old_gl = Process.group_leader()                  # remember current GL (terminal)
Process.group_leader(self(), file)               # point ours at the file
try do
  fun.()                                         # commands here use the new GL
after
  Process.group_leader(self(), old_gl)           # always restore
  File.close(file)
end
```

While `fun.()` runs, any `IO.write` from the calling process sends its message
to the file IO server, which writes bytes into `out.log` instead of the
terminal. The command has no idea — it's still just calling `IO.write`.

This is cleaner than `dup2`-ing fds (the C equivalent), and it's contained —
only the calling process is affected. Other processes still write to the
terminal.

---

## 8. Ports (subprocess execution)

### How shells normally run other programs

When you type `ls -la`, a shell:

1. Forks itself into a child process (`fork()` syscall).
2. In the child, replaces its image with `/bin/ls` (`execve()` syscall).
3. In the parent, waits for the child to exit (`waitpid()` syscall).

The child inherits the parent's fds for stdin/stdout/stderr — that's how
`ls`'s output ends up in the terminal.

### Why BEAM uses Ports instead

BEAM is a tightly-controlled VM with garbage collection, schedulers, and
millions of concurrent processes. You can't `fork()` it — that would
duplicate the VM. So BEAM provides a managed abstraction called a **Port**.

When you do `Port.open({:spawn_executable, "/bin/ls"}, [...])`:

1. BEAM forks once to create a tiny C-level helper.
2. The helper executes `/bin/ls`, connecting its stdin/stdout to pipes back
   into BEAM.
3. BEAM exposes that pipe pair as a Port reference.

From your Elixir process's perspective, you've created a thing you can:

- Send data to (writes go to the program's stdin)
- Receive messages from (`{port, {:data, "..."}}` for each chunk of stdout)
- Be notified about exit (`{port, {:exit_status, n}}`)

It's like a process, but it's actually a thin handle over fork+exec+pipes.

### In our code (`lib/commands/execute.ex`)

```elixir
port =
  Port.open({:spawn_executable, path}, [
    :binary,           # deliver data as binaries, not charlists
    :exit_status,      # send :exit_status when child dies
    :use_stdio,        # connect to child's stdin/stdout
    arg0: Path.basename(path),
    args: args
  ])

loop(port)
```

The message-receive loop:

```elixir
defp loop(port) do
  receive do
    {^port, {:data, data}} ->
      IO.write(data)       # forward child's stdout
      loop(port)
    {^port, {:exit_status, _code}} ->
      :ok
  end
end
```

The `^port` is a pin operator — "match this exact port, don't bind a new
variable named `port`."

### Why route through `IO.write`?

Why not let the child's output go directly to fd 1? Because then redirects
wouldn't work. By having the child's output come back to us as messages and
writing it via `IO.write`, the group-leader trick from §7 kicks in: if the
user wrote `ls > out.log`, the data flows through our group leader (swapped
to a file), and ends up in the file.

Ports are the bridge between external programs and the IO-server pipeline
that built-ins use. Same redirection mechanism works for both.

---

## 9. Hand-rolled tokenizer (state machines)

### What a state machine is

A **state machine** describes behavior that depends on history. Instead of
"do thing X," it's "do thing X if you're currently in state Y."

Example — a turnstile:

- States: `:locked`, `:unlocked`.
- Inputs: `:coin`, `:push`.
- Transitions:
  - `:locked + :coin → :unlocked`
  - `:unlocked + :push → :locked`
  - Everything else: no change.

You can draw it as a graph or write it as a function:
`next_state(current_state, input) → new_state`.

### Why shells need one

A line like `echo "hello world"` looks simple but isn't trivial to split:

- Spaces inside `"..."` are part of a token, not separators.
- A backslash inside `"..."` only escapes certain characters.
- Single quotes are stricter than double quotes (no escaping at all).
- An empty `""` is still a valid empty token.

You can't do this with `String.split`. The meaning of each character depends
on **what kind of quote you're currently inside**. That's state.

### Our state machine

States in `tokenize/5`:

| State | Meaning |
| --- | --- |
| `:none` | Not inside any quotes |
| `:single` | Inside `'...'` |
| `:double` | Inside `"..."` |

Transitions:

| Current state | Input | Next state | Effect |
| --- | --- | --- | --- |
| `:none` | `'` | `:single` | begin quoted token |
| `:none` | `"` | `:double` | begin quoted token |
| `:none` | `\` then X | `:none` | append X literally |
| `:none` | space/tab | `:none` | end token (if non-empty) |
| `:none` | other | `:none` | append char |
| `:single` | `'` | `:none` | exit quote |
| `:single` | anything | `:single` | append char |
| `:double` | `"` | `:none` | exit quote |
| `:double` | `\` then X in `{$, \`, ", \}` | `:double` | append X |
| `:double` | other | `:double` | append char |

Each row of that table is one Elixir function clause. Pattern matching picks
the right clause based on the current input and state.

The arguments to `tokenize/5`:

```
tokenize(remaining_input, tokens_so_far_reversed, current_token, mode, has_token?)
```

`has_token?` is needed to handle empty quoted strings: typing `""` should
produce one empty token, not zero tokens. Without the flag we couldn't tell
"between tokens" apart from "started a token but it's empty."

### Walking the bytes — `echo "hi there"`

```
(`echo "hi there"`, [], "", :none, false)
'e' → buf="e",  has=true
'c' → buf="ec"
'h' → buf="ech"
'o' → buf="echo"
' ' → push "echo"; ([... ["echo"]], "", :none, false)
'"' → enter :double; has=true
'h' → buf="h",  in :double
'i' → buf="hi"
' ' → literal space in :double; buf="hi "
't','h','e','r','e' → buf="hi there"
'"' → exit :double; back to :none, has=true
EOF, has=true → push "hi there"; reverse → ["echo", "hi there"]
```

The tokenizer doesn't know `>` is a redirect operator. It just produces
tokens. The caller (`extract_stdout_redirect`) recognizes `>` in the token
list and acts on it. Tokenize what's there; interpret it elsewhere.

---

## End-to-end: tracing `ech<TAB>`, Enter

This pulls all the concepts together. The user types `ech<TAB>` then Enter.

```
[wrapper script]
  stty -icanon -echo min 1     ← §3 (raw mode)
  exec /tmp/.../escript

[main/1]
  :io.setopts(:standard_io, binary: true)   ← §4 (IO server config)
  listen()

[listen/0]
  IO.write("$ ")                ← terminal shows "$ "
  read_line("")

[read_line, iteration 1]
  read_byte blocks in :io.get_chars
  User presses 'e' → kernel delivers 0x65
  read_byte returns 101         ← §2 (binary -> integer)
  regular-char branch:
    IO.write("e")               ← §5 (manual echo) → terminal: "$ e"
    recurse with buf="e"

[read_line, iteration 2]
  User presses 'c' → 99
  IO.write("c") → "$ ec"
  buf="ec"

[read_line, iteration 3]
  User presses 'h' → 104
  IO.write("h") → "$ ech"
  buf="ech"

[read_line, iteration 4]
  User presses TAB → 9         ← §6 (control character)
  handle_tab("ech"):
    matches "echo" uniquely
    writes "o " to terminal    → "$ echo "
    returns "echo "
  recurse with buf="echo "

[read_line, iteration 5]
  User presses Enter → 13      ← §6 (control character)
  IO.write("\r\n") → newline   ← §5 (manual newline)
  return "echo "

[back in listen/0]
  process_line("echo ")

[process_line]
  decode_console_input("echo ") → tokenize → ["echo"]   ← §9 (state machine)
  dispatch("echo", [])

[dispatch]
  No redirects detected.
  with_stdout_redirect(nil, fn -> run_command("echo", [], nil) end)

[run_command]
  Commands.executable_in_path?("echo") → {:ok, "/bin/echo"}
  Execute.execute(["/bin/echo", []])

[Execute.execute]
  Port.open(...)               ← §8 (subprocess via Port)
  loop(port) receives:
    {port, {:data, "\n"}} → IO.write("\n")   ← §7 (via group leader)
    {port, {:exit_status, 0}} → :ok

[back in listen/0]
  Tail-call into listen() again. New prompt printed.
```

Every concept in this file has a job in that trace. That's why a shell is
such a good systems-programming exercise: every layer of the Unix model shows
up.
