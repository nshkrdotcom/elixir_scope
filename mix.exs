defmodule ElixirScope.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_scope,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.smoke": :test,
        "test.all": :test,
        "dev.check": :dev,
        "ci.test": :test
      ],

      # Documentation
      name: "ElixirScope",
      docs: [
        main: "ElixirScope",
        extras: ["README.md"]
      ],

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [
          :error_handling,
          # :race_conditions,
          :underspecs
        ],
        ignore_warnings: ".dialyzer.ignore.exs",
        # Only include your app in the PLT
        plt_add_apps: [:elixir_scope],
        # Exclude test support files from analysis
        paths: ["_build/dev/lib/elixir_scope/ebin"]
        # plt_ignore_apps: [:some_dep] # Ignore specific dependencies
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ElixirScope.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core Foundation Layer
      {:foundation, "~> 0.1.0"},

      # Graph algorithms library
      {:libgraph, "~> 0.16"},

      # Development & Testing
      {:mox, "~> 1.2", only: [:dev, :test]},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      # Testing aliases
      "test.smoke": ["test test/smoke/ --trace"],
      "test.all": ["test"],

      # Quality assurance
      "qa.format": ["format --check-formatted"],
      "qa.credo": ["credo --strict"],
      "qa.dialyzer": ["dialyzer"],
      "qa.all": ["qa.format", "qa.credo", "compile --warnings-as-errors", "qa.dialyzer"],

      # Development workflow
      "dev.check": ["qa.format", "qa.credo", "compile", "test.smoke"],

      # CI workflow
      "ci.test": ["qa.all", "test.all"],

      # Setup
      setup: ["deps.get", "compile"]
    ]
  end
end
