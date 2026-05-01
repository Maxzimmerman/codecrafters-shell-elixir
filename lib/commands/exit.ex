defmodule Commands.Exit do
  @behaviour Commands.Command

  def execute do
    System.halt(0)
  end
end
