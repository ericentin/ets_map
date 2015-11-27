defmodule ETSDictTest do
  use ExUnit.Case, async: true

  test "put" do
    dict = ETSDict.new |> ETSDict.put(:hello, :world)

    assert :ets.lookup(dict.table, :hello) == [hello: :world]
  end

  test "fetch" do
    dict = ETSDict.new

    assert ETSDict.fetch(dict, :hello) == :error

    dict = ETSDict.put(dict, :hello, :world)

    assert ETSDict.fetch(dict, :hello) == {:ok, :world}
  end

  test "delete" do
    dict = ETSDict.new |> ETSDict.put(:hello, :world) |> ETSDict.delete(:hello)

    assert ETSDict.fetch(dict, :hello) == :error
  end

  test "reduce" do
    dict =
      ETSDict.new
      |> ETSDict.put(:a, 1)
      |> ETSDict.put(:b, 2)
      |> ETSDict.put(:c, 3)

    reduced =
      Enum.reduce dict, {[], 0}, fn {k, v}, {acc_k, acc_v} ->
        {[k | acc_k], acc_v + v}
      end

    assert reduced == {[:a, :b, :c], 6}
  end
end
