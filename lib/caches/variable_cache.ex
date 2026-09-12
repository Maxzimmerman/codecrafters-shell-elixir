defmodule VariableCache do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, {[], 0}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:get_one, variable}, _from, state) do
    case Enum.find(state, :not_found, &(&1 == variable)) do
      :not_found ->
        {:reply, :not_found, state}

      var ->
        {:reply, var, state}
    end
  end

  @impl true
  def handle_cast({:add_one, %{} = variable}, [history, appended]) do
    {:noreply, {[variable | history], appended}}
  end

  def get_all, do: GenServer.call(__MODULE__, :get_all)
  def get_one(variable), do: GenServer.call(__MODULE__, {:get_one, variable})
  def add_one(variable), do: GenServer.cast(__MODULE__, {:add_one, variable})
end
