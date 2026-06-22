defmodule Commands.Jobs do
  @behaviour Command

  @impl true
  def execute(_args) do
    IO.puts("CALLED")
  end
end
