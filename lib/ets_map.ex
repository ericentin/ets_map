defmodule ETSMap do
  @moduledoc """

  """
  defstruct [:table]

  @compile {:inline, delete: 2, fetch: 2, put: 3}

  def new(name \\ :ets_map_table, opts \\ [:set, :public]) do
    %__MODULE__{table: :ets.new(name, opts)}
  end

  def delete(%__MODULE__{table: table}) do
    :ets.delete(table)

    :ok
  end

  def delete(%__MODULE__{table: table} = map, key) do
    :ets.delete(table, key)

    map
  end

  def fetch(%__MODULE__{table: table}, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  def get_and_update(%__MODULE__{} = map, key, fun) do
    current_value = case fetch(map, key) do
      {:ok, value} -> value
      :error -> nil
    end

    {get, update} = fun.(current_value)
    {get, put(map, key, update)}
  end

  def put(%__MODULE__{table: table} = map, key, value) do
    :ets.insert(table, {key, value})

    map
  end

  def size(%__MODULE__{table: table}) do
    :ets.info(table, :size)
  end

  def to_list(%__MODULE__{table: table}) do
    :ets.tab2list(table)
  end

  defimpl Enumerable do
    def count(map),
      do: {:ok, ETSMap.size(map)}

    def member?(map, {key, value}) do
      case ETSMap.fetch(map, key) do
        {:ok, ^value} -> {:ok, true}
        _ -> {:ok, false}
      end
    end

    def member?(_, _),
      do: {:ok, false}

    def reduce(map, acc, fun),
      do: Enumerable.List.reduce(ETSMap.to_list(map), acc, fun)
  end

  defimpl Collectable do
    def into(original) do
      {original, fn
        map, {:cont, {key, value}} -> ETSMap.put(map, key, value)
        map, :done -> map
        _, :halt -> :ok
      end}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(map, opts) do
      concat ["#ETSMap<table: #{map.table}, ", Inspect.List.inspect(ETSMap.to_list(map), opts), ">"]
    end
  end
end
