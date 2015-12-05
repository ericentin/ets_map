defmodule ETSMap.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [app: :ets_map,
     version: @version,
     elixir: "~> 1.1",
     description: description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     name: "ETSMap",
     docs: [source_ref: "v#{@version}", main: "ETSMap",
            source_url: "https://github.com/antipax/ets_map"]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, "~> 0.11.1", only: [:dev, :test]},
      {:credo, "~> 0.1.9", only: [:dev, :test]},
      {:dialyze, "~> 0.2.0", only: [:dev, :test]}
    ]
  end

  defp description do
    "A Map-like Elixir data structure that is backed by an ETS table."
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Eric Entin"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/antipax/ets_map"
      }
    ]
  end
end
