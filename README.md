# ETSMap

A Map-like Elixir data structure that is backed by an ETS table.

## Installation

The package can be installed by:

  1. Adding ets_map to your list of dependencies in `mix.exs`:

        def deps do
          [{:ets_map, "~> 0.0.1"}]
        end

  2. Ensuring ets_map is started before your application:

        def application do
          [applications: [:ets_map]]
        end
