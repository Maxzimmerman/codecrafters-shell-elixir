defmodule DataTypes.BackgroundJob do
  defstruct [:job_number, :process_id, :command_str, :status]
end
