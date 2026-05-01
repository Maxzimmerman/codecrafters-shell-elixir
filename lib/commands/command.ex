defmodule Commands.Command do
  @callback execute() :: any()
end
