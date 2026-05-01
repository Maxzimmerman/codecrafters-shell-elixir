defmodule Commands.Exit do
  @behaviour Commands.Command

  def execute(_args) do
    System.halt(0)
  end
end
