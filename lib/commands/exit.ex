defmodule Commands.Exit do
  @behaviour Commands.Command

  def execute(_args) do
    CLI.write_to_hist_file()
    System.halt(0)
  end
end
