defmodule ETSMapTest do
  use ExUnit.Case, async: true

  test "put" do
    dict = ETSMap.new |> ETSMap.put(:hello, :world)

    assert :ets.lookup(dict.table, :hello) == [hello: :world]
  end

  test "fetch" do
    dict = ETSMap.new

    assert ETSMap.fetch(dict, :hello) == :error

    dict = ETSMap.put(dict, :hello, :world)

    assert ETSMap.fetch(dict, :hello) == {:ok, :world}
  end

  test "delete" do
    dict = ETSMap.new |> ETSMap.put(:hello, :world) |> ETSMap.delete(:hello)

    assert ETSMap.fetch(dict, :hello) == :error
  end

  test "reduce" do
    dict =
      ETSMap.new
      |> ETSMap.put(:a, 1)
      |> ETSMap.put(:b, 2)
      |> ETSMap.put(:c, 3)

    reduced =
      Enum.reduce dict, {[], 0}, fn {k, v}, {acc_k, acc_v} ->
        {[k | acc_k], acc_v + v}
      end

    assert reduced == {[:a, :b, :c], 6}
  end

  test "access" do
    dict =
      ETSMap.new
      |> ETSMap.put(:a, 1)

    assert dict[:a] == 1
  end

  test "put_in" do
    map = ETSMap.new

    dict = put_in map[:a], %{b: 2}

    assert dict[:a][:b] == 2
  end
end
