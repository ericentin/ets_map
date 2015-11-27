defmodule ETSDict do
  use Dict

  defstruct [:table]

  @compile {:inline, delete: 2, fetch: 2, put: 3}

  def new(name \\ :ets_dict_table, opts \\ [:set, :public]) do
    %__MODULE__{table: :ets.new(name, opts)}
  end

  def delete(%__MODULE__{table: table}) do
    :ets.delete(table)

    :ok
  end

  def delete(%__MODULE__{table: table} = dict, key) do
    :ets.delete(table, key)

    dict
  end

  def fetch(%__MODULE__{table: table}, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  def put(%__MODULE__{table: table} = dict, key, value) do
    :ets.insert(table, {key, value})

    dict
  end

  @doc false
  def reduce(%__MODULE__{} = dict, acc, fun) do
    Enumerable.List.reduce(to_list(dict), acc, fun)
  end

  def size(%__MODULE__{table: table}) do
    :ets.info(table, :size)
  end

  def to_list(%__MODULE__{table: table}) do
    :ets.tab2list(table)
  end

  defimpl Enumerable do
    def count(dict),
      do: {:ok, ETSDict.size(dict)}

    def member?(dict, {key, value}) do
      case ETSDict.fetch(dict, key) do
        {:ok, ^value} -> {:ok, true}
        _ -> {:ok, false}
      end
    end

    def member?(_, _),
      do: {:ok, false}

    def reduce(dict, acc, fun),
      do: ETSDict.reduce(dict, acc, fun)
  end

  defimpl Collectable do
    def into(original) do
      {original, fn
        dict, {:cont, {key, value}} -> ETSDict.put(dict, key, value)
        dict, :done -> dict
        _, :halt -> :ok
      end}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(dict, opts) do
      concat ["#ETSDict<table: #{dict.table}, ", Inspect.List.inspect(ETSDict.to_list(dict), opts), ">"]
    end
  end
end
