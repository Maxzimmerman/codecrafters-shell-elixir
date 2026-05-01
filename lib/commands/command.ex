defmodule Commands.Command do
  @callback execute(binary()) :: any()
end
