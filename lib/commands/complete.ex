defmodule Commands.Complete do
  @behaviour Commands.Command

  alias Commands

  @registered []

  def execute(["-p", executable | _] = args) do
    if executable in @registered do
      IO.print("valid")
    else
      IO.print("not valid")
    end
  end
end
