defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  @registered []

  def execute(["-p", executable | _] = args) do
    if executable in @registered do
      IO.write("")
    else
      IO.write("complete: systemctl: no completion specification")
    end
  end
end
