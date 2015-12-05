defmodule ETSMap do
  @moduledoc """
  `ETSMap` is a [`Map`](http://elixir-lang.org/docs/stable/elixir/Map.html)-like
  Elixir data structure that is backed by an
  [ETS](http://www.erlang.org/doc/man/ets.html) table.

  *If you are not familiar with ETS, you should first familiarize yourself with
  it before using this module. This is not a drop-in replacement for the
  [`Map`](http://elixir-lang.org/docs/stable/elixir/Map.html) module. There are
  many critically important differences between a regular
  [`Map`](http://elixir-lang.org/docs/stable/elixir/Map.html) and an `ETSMap`.*

  That being said, being able to use the Elixir
  [`Map`](http://elixir-lang.org/docs/stable/elixir/Map.html) API with an ETS
  table is a nice convenience. If necessary, you can always use the normal ETS
  API by retrieving the underlying ETS table via the `ETSMap` struct field
  `table`.

  ## Access

  `ETSMap` supports the [`Access`](http://elixir-lang.org/docs/stable/elixir/Access.html) protocol,
  so you can use the access syntax:

      iex> ets_map[:key]
      :value

  as well as the *_in family of functions from
  [`Kernel`](http://elixir-lang.org/docs/stable/elixir/Kernel.html):

      iex> put_in ets_map[:key], :value
      #ETSMap<table: ..., [key: :value]>

  ## Enumerable

  `ETSMap` supports the
  [`Enumerable`](http://elixir-lang.org/docs/stable/elixir/Enumerable.html)
  protocol, so all of the functions in
  [`Enum`](http://elixir-lang.org/docs/stable/elixir/Enum.html)
  and [`Stream`](http://elixir-lang.org/docs/stable/elixir/Stream.html) work
  as expected, as well as for comprehensions:

      iex> Enum.map ets_map, fn {key, value} ->
        {key, value + 1}
      end
      [b: 3, a: 2]

      iex> for {key, value} <- ets_map, do: {key, value + 1}
      [b: 3, a: 2]

  ## Collectable

  `ETSMap` also supports the
  [`Collectable`](http://elixir-lang.org/docs/stable/elixir/Collectable.html)
  protocol, so
  [`Enum.into`](http://elixir-lang.org/docs/master/elixir/Enum.html#into/2) and
  [`Stream.into`](http://elixir-lang.org/docs/master/elixir/Stream.html#into/3)
  will function as expected, as well:

      iex> ets_map = [a: 1, b: 2] |> Enum.into(ETSMap.new)
      #ETSMap<table: ..., [b: 2, a: 1]>

      iex> [c: 3, d: 4] |> Enum.into(ets_map)
      #ETSMap<table: ..., [d: 4, c: 3, b: 2, a: 1]>

      iex> for {k, v} <- ets_map, into: ets_map, do: {k, v + 1}
      #ETSMap<table: ..., [d: 5, c: 4, b: 3, a: 2]>

      iex> ets_map
      #ETSMap<table: ..., [d: 5, c: 4, b: 3, a: 2]>

  ## ETSMap vs. Map Semantics

  This section should not be considered an exhaustive specification of the
  behavior of ETS (which you can find in the official ETS docs that you
  should have read already). The intention, instead, is to cover some of the
  largest differences that this behavior manifests between
  [`Map`](http://elixir-lang.org/docs/stable/elixir/Map.html)s and `ETSMap`s.

  One of the important differences between a
  [`Map`](http://elixir-lang.org/docs/stable/elixir/Map.html) and an `ETSMap`
  is that `ETSMap`s are not immutable. Thus, any functions which would normally
  return a new (modified) copy of the input value will actually mutate all
  references to that value. However, this has the advantage of allowing the
  `ETSMap`/table to be written and read from multiple processes concurrently.

  ETS tables are linked to their owner. By default, a table's owner is the
  process that created it. If the process that created it dies, the table will
  be deleted, even if references to it still exist in other processes. If no
  references to a table still exist, and the table's owner still exists, the
  table will be leaked. Ultimately `ETSMap`s are backed by ETS tables, so this
  behavior is important to keep in mind.
  """

  defstruct [:table]

  @opaque t :: %__MODULE__{table: :ets.tab}
  @type key :: any
  @type value :: any
  @type new_opts :: [new_opt]
  @type new_opt ::
    {:enumerable, Enum.t} |
    {:transform, ({key, value} -> {key, value})} |
    {:name, atom} |
    {:ets_opts, Keyword.t}

  @compile {:inline, delete: 2, fetch: 2, put: 3}

  @doc """
  Returns a new `ETSMap`.

  If the appropriate options are provided, will call
  [`:ets.new`](http://www.erlang.org/doc/man/ets.html#new-2) to create table
  `name` using options `ets_opts` and then insert `enumerable`, using
  `transform` to transform the elements.

  By default, `name` is set to `:ets_map_table` and `ets_opts` is set to
  `[:set, :public]`. The only supported table types are `:set`
  and `:ordered_set`.

  There is also a convenience clause provided which takes a single argument (a
  map) which is inserted into the new `ETSMap`

  ## Examples
      iex> ETSMap.new(enumerable: %{a: 1, b: 2}, transform: fn {k, v} -> {k, v + 1} end)
      #ETSMap<table: ..., [b: 3, a: 2]>
      iex> ETSMap.new(%{a: 1})
      #ETSMap<table: ..., [a: 2]>
  """
  @spec new(map | new_opts) :: t
  def new(opts \\ [])

  def new(%{} = map) do
    new(enumerable: map)
  end

  def new(opts) do
    enumerable = Keyword.get(opts, :enumerable, [])
    transform = Keyword.get(opts, :transform, fn x -> x end)
    name = Keyword.get(opts, :name, :ets_map_table)
    ets_opts = Keyword.get(opts, :ets_opts, [:set, :public])

    ets_map = %__MODULE__{table: :ets.new(name, ets_opts)}

    :ets.insert(ets_map.table, enumerable |> Enum.map(transform))

    ets_map
  end

  @doc """
  Deletes an `ETSMap` using [`:ets.delete`](http://www.erlang.org/doc/man/ets.html#delete-1).
  """
  @spec delete(t) :: :ok
  def delete(%__MODULE__{} = map) do
    :ets.delete(map.table)

    :ok
  end

  @doc """
  Deletes the entries for a specific `key`.

  If the `key` does not exist, does nothing.

  ## Examples
      iex> ETSMap.delete(ETSMap.new(%{a: 1, b: 2}), :a)
      #ETSMap<table: ..., [b: 2]>
      iex> ETSMap.delete(ETSMap.new(%{b: 2}), :a)
      #ETSMap<table: ..., [b: 2]>
  """
  @spec delete(t, key) :: t
  def delete(%__MODULE__{table: table} = map, key) do
    :ets.delete(table, key)

    map
  end

  @doc """
  Drops the given keys from the map.

  ## Examples
      iex> ETSMap.drop(ETSMap.new(%{a: 1, b: 2, c: 3}), [:b, :d])
      #ETSMap<table: ..., [a: 1, c: 3]>
  """
  @spec drop(t, [key]) :: t
  def drop(%__MODULE__{} = map, keys) do
    Enum.reduce(keys, map, &delete(&2, &1))
  end

  @doc """
  Checks if two `ETSMap`s are equal.

  Two maps are considered to be equal if they contain
  the same keys and those keys contain the same values.

  ## Examples
      iex> ETSMap.equal?(ETSMap.new(%{a: 1, b: 2}), ETSMap.new(%{b: 2, a: 1}))
      true
      iex> ETSMap.equal?(ETSMap.new(%{a: 1, b: 2}), ETSMap.new(%{b: 1, a: 2}))
      false
  """
  @spec equal?(t, t) :: boolean
  def equal?(%__MODULE__{} = map1, %__MODULE__{} = map2), do: to_list(map1) === to_list(map2)

  @doc """
  Fetches the value for a specific `key` and returns it in a tuple.

  If the `key` does not exist, returns `:error`.

  ## Examples
      iex> ETSMap.fetch(ETSMap.new(%{a: 1}), :a)
      {:ok, 1}
      iex> ETSMap.fetch(ETSMap.new(%{a: 1}), :b)
      :error
  """
  @spec fetch(t, key) :: {:ok, value} | :error
  def fetch(%__MODULE__{} = map, key) do
    case :ets.lookup(map.table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  @doc """
  Fetches the value for specific `key`.

  If `key` does not exist, a `KeyError` is raised.

  ## Examples
      iex> ETSMap.fetch!(ETSMap.new(%{a: 1}), :a)
      1
      iex> ETSMap.fetch!(ETSMap.new(%{a: 1}), :b)
      ** (KeyError) key :b not found in: #ETSMap<table: ..., [a: 1]>
  """
  @spec fetch!(t, key) :: value | no_return
  def fetch!(%__MODULE__{} = map, key) do
    case fetch(map, key) do
      {:ok, value} -> value
      :error -> raise KeyError, key: key, term: map
    end
  end

  @doc """
  Gets the value for a specific `key`.

  If `key` does not exist, return the default value
  (`nil` if no default value).

  ## Examples
      iex> ETSMap.get(ETSMap.new(%{}), :a)
      nil
      iex> ETSMap.get(ETSMap.new(%{a: 1}), :a)
      1
      iex> ETSMap.get(ETSMap.new(%{a: 1}), :b)
      nil
      iex> ETSMap.get(ETSMap.new(%{a: 1}), :b, 3)
      3
  """
  @spec get(t, key, value) :: value
  def get(%__MODULE__{} = map, key, default \\ nil) do
    case fetch(map, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @doc """
  Gets the value for a specific `key`.

  If `key` does not exist, lazily evaluates `fun` and returns its result.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples
      iex> map = ETSMap.new(%{a: 1})
      iex> fun = fn ->
      ...>   # some expensive operation here
      ...>   13
      ...> end
      iex> ETSMap.get_lazy(map, :a, fun)
      1
      iex> ETSMap.get_lazy(map, :b, fun)
      13
  """
  @spec get_lazy(t, key, (() -> value)) :: value
  def get_lazy(%__MODULE__{} = map, key, fun) when is_function(fun, 0) do
    case fetch(map, key) do
      {:ok, value} -> value
      :error -> fun.()
    end
  end

  @doc """
  Gets the value from `key` and updates it, all in one pass.

  This `fun` argument receives the value of `key` (or `nil` if `key`
  is not present) and must return a two-elements tuple: the "get" value (the
  retrieved value, which can be operated on before being returned) and the new
  value to be stored under `key`.

  The returned value is a tuple with the "get" value returned by `fun` and a
  new map with the updated value under `key`.

  ## Examples
      iex> ETSMap.get_and_update(ETSMap.new(%{a: 1}), :a, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {1, #ETSMap<table: ..., [a: "new value!"]>}
      iex> ETSMap.get_and_update(ETSMap.new(%{a: 1}), :b, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {nil, #ETSMap<table: ..., [b: "new value!", a: 1]>}
  """
  @spec get_and_update(t, key, (value -> {get, value})) :: {get, t} when get: value
  def get_and_update(%__MODULE__{} = map, key, fun) do
    current_value = case fetch(map, key) do
      {:ok, value} -> value
      :error -> nil
    end

    {get, update} = fun.(current_value)
    {get, put(map, key, update)}
  end

  @doc """
  Gets the value from `key` and updates it. Raises if there is no `key`.

  This `fun` argument receives the value of `key` and must return a
  two-elements tuple: the "get" value (the retrieved value, which can be
  operated on before being returned) and the new value to be stored under
  `key`.

  The returned value is a tuple with the "get" value returned by `fun` and a
  new map with the updated value under `key`.

  ## Examples
      iex> ETSMap.get_and_update(ETSMap.new(%{a: 1}), :a, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {1, #ETSMap<table: ..., [a: "new value!"]>}
      iex> ETSMap.get_and_update(ETSMap.new(%{a: 1}), :b, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      ** (KeyError) key :b not found
  """
  @spec get_and_update!(t, key, (value -> {get, value})) :: {get, t} | no_return when get: value
  def get_and_update!(%__MODULE__{} = map, key, fun) do
    case fetch(map, key) do
      {:ok, value} ->
        {get, update} = fun.(value)
        {get, :maps.put(key, update, map)}
      :error ->
        :erlang.error({:badkey, key})
    end
  end

  @doc """
  Returns whether a given `key` exists.

  ## Examples
      iex> ETSMap.has_key?(ETSMap.new(%{a: 1}), :a)
      true
      iex> ETSMap.has_key?(ETSMap.new(%{a: 1}), :b)
      false
  """
  @spec has_key?(t, key) :: boolean
  def has_key?(%__MODULE__{} = map, key),
    do: match? {:ok, _}, fetch(map, key)

  @doc """
  Returns all keys.

  ## Examples
      iex> ETSMap.keys(ETSMap.new(%{a: 1, b: 2}))
      [:a, :b]
  """
  @spec keys(t) :: [key]
  def keys(%__MODULE__{} = map) do
    :ets.select(map.table, [{{:"$1", :"_"}, [], [:"$1"]}])
  end

  @doc """
  Merges two maps into one.

  All keys in `map2` will be added to `map1`, overriding any existing one.

  ## Examples
      iex> ETSMap.merge(ETSMap.new(%{a: 1, b: 2}), ETSMap.new(%{a: 3, d: 4}))
      #ETSMap<table: ..., [d: 4, b: 2, a: 3]>
      iex> ETSMap.merge(ETSMap.new(%{a: 1, b: 2}), %{a: 3, d: 4})
      #ETSMap<table: ..., [d: 4, b: 2, a: 3]>
  """
  @spec merge(Enum.t, Enum.t) :: Enum.t
  def merge(%__MODULE__{} = map1, map2) do
    map2 |> Enum.into(map1)
  end

  @doc """
  Merges two maps into one.

  All keys in `map2` will be added to `map1`. The given function will
  be invoked with the key, value1 and value2 to solve conflicts.

  ## Examples
      iex> ETSMap.merge(ETSMap.new(%{a: 1, b: 2}), %{a: 3, d: 4}, fn _k, v1, v2 ->
      ...>   v1 + v2
      ...> end)
      #ETSMap<table: ..., [a: 4, b: 2, d: 4]>
  """
  @spec merge(Enum.t, Enum.t, (key, value, value -> value)) :: map
  def merge(%__MODULE__{} = map1, map2, callback) do
    Enum.reduce map2, map1, fn {k, v2}, acc ->
      update(acc, k, v2, fn(v1) -> callback.(k, v1, v2) end)
    end
  end

  @doc """
  Returns and removes all values associated with `key`.

  ## Examples
      iex> ETSMap.pop(ETSMap.new(%{a: 1}), :a)
      {1, #ETSMap<table: ..., []>}
      iex> ETSMap.pop(%{a: 1}, :b)
      {nil, #ETSMap<table: ..., [a: 1]>}
      iex> ETSMap.pop(%{a: 1}, :b, 3)
      {3, #ETSMap<table: ..., [a: 1]>}
  """
  @spec pop(t, key, value) :: {value, t}
  def pop(%__MODULE__{} = map, key, default \\ nil) do
    case fetch(map, key) do
      {:ok, value} -> {value, delete(map, key)}
      :error -> {default, map}
    end
  end

  @doc """
  Lazily returns and removes all values associated with `key` in the `map`.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples
      iex> map = ETSMap.new(%{a: 1})
      iex> fun = fn ->
      ...>   # some expensive operation here
      ...>   13
      ...> end
      iex> ETSMap.pop_lazy(map, :a, fun)
      {1, #ETSMap<table: ..., []>}
      iex> ETSMap.pop_lazy(map, :a, fun)
      {13, #ETSMap<table: ..., []>}
  """
  @spec pop_lazy(t, key, (() -> value)) :: {value, t}
  def pop_lazy(%__MODULE__{} = map, key, fun) when is_function(fun, 0) do
    case fetch(map, key) do
      {:ok, value} -> {value, delete(map, key)}
      :error -> {fun.(), map}
    end
  end

  @doc """
  Puts the given `value` under `key`.

  ## Examples
      iex> ETSMap.put(ETSMap.new(%{a: 1}), :b, 2)
      #ETSMap<table: ..., [a: 1, b: 2]>
      iex> ETSMap.put(ETSMap.new(%{a: 1, b: 2}), :a, 3)
      #ETSMap<table: ..., [a: 3, b: 2]>
  """
  @spec put(map, key, value) :: map
  def put(%__MODULE__{table: table} = map, key, value) do
    :ets.insert(table, {key, value})

    map
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key`
  already exists.

  ## Examples
      iex> ETSMap.put_new(ETSMap.new(%{a: 1}), :b, 2)
      #ETSMap<table: ..., [b: 2, a: 1]>
      iex> ETSMap.put_new(ETSMap.new(%{a: 1, b: 2}), :a, 3)
      #ETSMap<table: ..., [a: 1, b: 2]>
  """
  @spec put_new(t, key, value) :: t
  def put_new(%__MODULE__{} = map, key, value) do
    case has_key?(map, key) do
      true  -> map
      false -> put(map, key, value)
    end
  end

  @doc """
  Evaluates `fun` and puts the result under `key`
  in map unless `key` is already present.
  This is useful if the value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples
      iex> map = ETSMap.new(%{a: 1})
      iex> fun = fn ->
      ...>   # some expensive operation here
      ...>   3
      ...> end
      iex> ETSMap.put_new_lazy(map, :a, fun)
      #ETSMap<table: ..., [a: 1]>
      iex> ETSMap.put_new_lazy(map, :b, fun)
      #ETSMap<table: ..., [a: 1, b: 3]>
  """
  @spec put_new_lazy(t, key, (() -> value)) :: map
  def put_new_lazy(%__MODULE__{} = map, key, fun) when is_function(fun, 0) do
    case has_key?(map, key) do
      true  -> map
      false -> put(map, key, fun.())
    end
  end

  @doc false
  def size(%__MODULE__{table: table}),
    do: :ets.info(table, :size)

  @doc """
  Takes all entries corresponding to the given keys and extracts them into a
  separate `ETSMap`.

  Returns a tuple with the new map and the old map with removed keys.

  Keys for which there are no entires in the map are ignored.

  ## Examples
      iex> ETSMap.split(ETSMap.new(%{a: 1, b: 2, c: 3}), [:a, :c, :e])
      {#ETSMap<table: ..., [a: 1, c: 3]>, #ETSMap<table: ..., [b: 2]>}
  """
  @spec split(t, [key], new_opts) :: t
  def split(%__MODULE__{} = map, keys, new_opts \\ []) do
    Enum.reduce(keys, {new(new_opts), map}, fn key, {inc, exc} = acc ->
      case fetch(exc, key) do
        {:ok, value} ->
          {put(inc, key, value), delete(exc, key)}
        :error ->
          acc
      end
    end)
  end

  @doc """
  Takes all entries corresponding to the given keys and
  returns them in a new `ETSMap`.

  ## Examples
      iex> ETSMap.take(ETSMap.new(%{a: 1, b: 2, c: 3}), [:a, :c, :e])
      #ETSMap<table: ..., [a: 1, c: 3]>
  """
  @spec take(t, [key], Keyword.t) :: t
  def take(%__MODULE__{} = map, keys, new_opts \\ []) do
    Enum.reduce(keys, new(new_opts), fn key, acc ->
      case fetch(map, key) do
        {:ok, value} -> put(acc, key, value)
        :error -> acc
      end
    end)
  end

  @doc """
  Converts the `ETSMap` to a list.

  ## Examples
      iex> ETSMap.to_list(ETSMap.new([a: 1]))
      [a: 1]
      iex> ETSMap.to_list(ETSMap.new(%{1 => 2}))
      [{1, 2}]
  """
  @spec to_list(t) :: [{key, value}]
  def to_list(%__MODULE__{} = map),
    do: :ets.tab2list(map.table)

  @doc """
  Updates the `key` in `map` with the given function.

  If the `key` does not exist, inserts the given `initial` value.

  ## Examples
      iex> ETSMap.update(ETSMap.new(%{a: 1}), :a, 13, &(&1 * 2))
      #ETSMap<table: ..., [a: 2]>
      iex> ETSMap.update(ETSMap.new(%{a: 1}), :b, 11, &(&1 * 2))
      #ETSMap<table: ..., [a: 1, b: 11]>
  """
  @spec update(t, key, value, (value -> value)) :: t
  def update(%__MODULE__{} = map, key, initial, fun) do
    case fetch(map, key) do
      {:ok, value} ->
        put(map, key, fun.(value))
      :error ->
        put(map, key, initial)
    end
  end

  @doc """
  Updates the `key` with the given function.

  If the `key` does not exist, raises `KeyError`.

  ## Examples
      iex> ETSMap.update!(ETSMap.new(%{a: 1}), :a, &(&1 * 2))
      #ETSMap<table: ..., [a: 2]>
      iex> ETSMap.update!(ETSMap.new(%{a: 1}), :b, &(&1 * 2))
      ** (KeyError) key :b not found
  """
  @spec update!(map, key, (value -> value)) :: map | no_return
  def update!(%__MODULE__{} = map, key, fun) do
    case fetch(map, key) do
      {:ok, value} ->
        put(map, key, fun.(value))
      :error ->
        :erlang.error({:badkey, key})
    end
  end

  @doc """
  Returns all values.

  ## Examples
      iex> ETSMap.values(ETSMap.new(%{a: 1, b: 2}))
      [1, 2]
  """
  @spec values(t) :: [value]
  def values(%__MODULE__{} = map) do
    :ets.select(map.table, [{{:"_", :"$1"}, [], [:"$1"]}])
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

    def member?(_map, _value),
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

    def inspect(map, opts),
      do: concat [
        "#ETSMap<table: #{map.table}, ",
        Inspect.List.inspect(ETSMap.to_list(map), opts),
        ">"
      ]
  end
end
