# `run_command/3` — external program vs built-in dispatch

`lib/main.ex:133-151`

```elixir
defp run_command(command, input, stderr_redirect) do
  case Commands.executable_in_path?(command) do
    {:ok, res} ->
      if stderr_redirect do
        Execute.execute([res, input, stderr_redirect])
      else
        Execute.execute([res, input])
      end

    {:error, :no_exe} ->
      try do
        command(command).execute(input)
      rescue
        _e in KeyError -> IO.puts("#{command}: not found")
      catch
        _error -> IO.puts("#{command}: not found")
      end
  end
end
```

## What it does

Given a command name, args, and an optional stderr redirect, run the command.
Two routes:

1. **External program in PATH** → spawn it via `Execute` (which uses an
   Erlang Port).
2. **Built-in** → look up the module in the `@commands` map and call its
   `execute/1`.

If neither path works, print `"<cmd>: not found"`.

## The lookup order — external first, built-in second

```elixir
case Commands.executable_in_path?(command) do
  {:ok, res} -> Execute.execute(...)
  {:error, :no_exe} -> command(command).execute(input)
end
```

This is **bash-like for non-shadowed commands** (e.g. `ls`, `cat`) but
technically reversed for shadowed names. Real bash looks up built-ins
first, so `echo` always runs the built-in even if `/bin/echo` exists.

For this challenge the difference doesn't matter — the test cases don't rely
on built-in priority. If a future stage needs strict bash semantics, swap
the order:

```elixir
try do
  command(command).execute(input)
rescue
  _ in KeyError ->
    case Commands.executable_in_path?(command) do
      {:ok, res} -> Execute.execute(...)
      _ -> IO.puts("#{command}: not found")
    end
end
```

## The two `Execute.execute/1` shapes

```elixir
Execute.execute([res, input, stderr_redirect])   # with stderr redirect
Execute.execute([res, input])                     # without
```

`Execute` pattern-matches on the shape of the list:

- 3-element form: build a `sh -c "cmd 2> file"` command string so the shell
  handles stderr redirection.
- 2-element form: spawn the executable directly via Port.

See [LEARNING.md §8](../LEARNING.md#8-ports-subprocess-execution) for how
Ports work.

## The built-in lookup

```elixir
command(command).execute(input)
```

`command/1` is defined elsewhere in `main.ex`:

```elixir
defp command(name) do
  Map.fetch!(@commands, name)
end
```

It looks up the name in the compile-time `@commands` map:

```elixir
@commands %{
  "exit" => Exit,
  "echo" => Echo,
  "type" => Type,
  "pwd"  => PWD,
  "cd"   => CD,
  "" => Execute
}
```

`Map.fetch!/2` raises `KeyError` on miss. That's the signal that the command
isn't a built-in either.

## The `try/rescue/catch` block

```elixir
try do
  command(command).execute(input)
rescue
  _e in KeyError -> IO.puts("#{command}: not found")
catch
  _error -> IO.puts("#{command}: not found")
end
```

Two failure modes:

- **`rescue _e in KeyError`** — catches the `KeyError` from `Map.fetch!` when
  the name isn't a built-in.
- **`catch _error`** — catches Erlang-style `throw` values. Belt-and-suspenders
  in case a built-in's `execute/1` throws unexpectedly.

Both print `"<cmd>: not found"` — even the second branch, which is a bit
misleading (a misbehaving built-in could appear as "not found"). For the
current test suite this hasn't mattered.

## Flow example A — external `ls`

```
run_command("ls", ["-la"], nil)
  Commands.executable_in_path?("ls") → {:ok, "/bin/ls"}
  Execute.execute(["/bin/ls", ["-la"]])
    Port.open spawns /bin/ls
    loop receives data, exit_status
```

## Flow example B — built-in `pwd`

```
run_command("pwd", [], nil)
  Commands.executable_in_path?("pwd") → {:error, :no_exe}  (not in PATH)
  command("pwd") → PWD module
  PWD.execute([])
    IO.puts(File.cwd!())
```

## Flow example C — unknown `foobar`

```
run_command("foobar", [], nil)
  Commands.executable_in_path?("foobar") → {:error, :no_exe}
  command("foobar") → Map.fetch! raises KeyError
  rescue clause → IO.puts("foobar: not found")
```

## Related concepts

- [LEARNING.md §8](../LEARNING.md#8-ports-subprocess-execution) — how external
  programs are run
- [code/dispatch.md](dispatch.md) — what calls `run_command` and sets up
  redirects
