
## config/config.exs (example configuration)
import Config

# ElixirScope Foundation Layer Configuration
config :elixir_scope,
  # AI Provider Configuration  
  ai: [
    provider: :mock,
    api_key: System.get_env("ELIXIR_SCOPE_AI_API_KEY"),
    model: "gpt-4",
    analysis: [
      max_file_size: 1_000_000,
      timeout: 30_000,
      cache_ttl: 3600
    ],
    planning: [
      default_strategy: :balanced,
      performance_target: 0.01,
      sampling_rate: 1.0
    ]
  ],

  # Capture Configuration
  capture: [
    ring_buffer: [
      size: 1024,
      max_events: 1000,
      overflow_strategy: :drop_oldest,
      num_buffers: :schedulers
    ],
    processing: [
      batch_size: 100,
      flush_interval: 50,
      max_queue_size: 1000
    ],
    vm_tracing: [
      enable_spawn_trace: true,
      enable_exit_trace: true,
      enable_message_trace: false,
      trace_children: true
    ]
  ],

  # Storage Configuration
  storage: [
    hot: [
      max_events: 100_000,
      max_age_seconds: 3600,
      prune_interval: 60_000
    ],
    warm: [
      enable: false,
      path: "./elixir_scope_data",
      max_size_mb: 100,
      compression: :zstd
    ],
    cold: [
      enable: false
    ]
  ],

  # Interface Configuration
  interface: [
    query_timeout: 10_000,
    max_results: 1000,
    enable_streaming: true
  ],

  # Development Configuration
  dev: [
    debug_mode: false,
    verbose_logging: false,
    performance_monitoring: true
  ]

# Import environment specific config
import_config "#{config_env()}.exs"

## config/dev.exs
import Config

# Development environment configuration
config :elixir_scope,
  dev: [
    debug_mode: true,
    verbose_logging: true,
    performance_monitoring: true
  ]

# Enable debug logging in development
config :logger, level: :debug

## config/test.exs
import Config

# Test environment configuration
config :elixir_scope,
  ai: [
    provider: :mock,
    analysis: [
      max_file_size: 100_000,  # Smaller for tests
      timeout: 5_000,          # Faster timeouts
      cache_ttl: 60
    ],
    planning: [
      default_strategy: :fast,
      performance_target: 0.1,
      sampling_rate: 1.0
    ]
  ],
  
  capture: [
    processing: [
      batch_size: 10,      # Smaller batches for tests
      flush_interval: 10,
      max_queue_size: 100
    ]
  ],

  dev: [
    debug_mode: false,     # Reduce noise in tests
    verbose_logging: false,
    performance_monitoring: false
  ]

# Configure test logging
config :logger, level: :warning

## config/prod.exs
import Config

# Production environment configuration
config :elixir_scope,
  ai: [
    provider: {:system, "ELIXIR_SCOPE_AI_PROVIDER", :openai},
    api_key: {:system, "ELIXIR_SCOPE_AI_API_KEY"},
    analysis: [
      max_file_size: 5_000_000,  # Larger files in production
      timeout: 60_000,           # More generous timeouts
      cache_ttl: 7200
    ],
    planning: [
      default_strategy: :balanced,
      performance_target: 0.005,  # Higher performance target
      sampling_rate: 0.1          # Lower sampling rate
    ]
  ],

  capture: [
    processing: [
      batch_size: 1000,
      flush_interval: 100,
      max_queue_size: 10_000
    ]
  ],

  storage: [
    warm: [
      enable: true,
      path: "/var/lib/elixir_scope/data",
      max_size_mb: 1000,
      compression: :zstd
    ],
    cold: [
      enable: true
    ]
  ],

  dev: [
    debug_mode: false,
    verbose_logging: false,
    performance_monitoring: true
  ]

# Production logging configuration
config :logger, level: :info

## mix.exs (Foundation layer dependencies)
defmodule ElixirScope.Foundation.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_scope_foundation,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      
      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.unit": :test,
        "test.smoke": :test
      ],

      # Documentation
      name: "ElixirScope Foundation",
      docs: [
        main: "ElixirScope.Foundation",
        extras: ["README.md"]
      ],

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {ElixirScope.Foundation.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      
      # Development and testing
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      # Testing aliases
      "test.unit": ["test test/unit/"],
      "test.smoke": ["test test/smoke/ --trace"],
      "test.contract": ["test test/contract/"],
      "test.all": ["test"],
      
      # Quality assurance
      "qa.format": ["format --check-formatted"],
      "qa.credo": ["credo --strict"],
      "qa.dialyzer": ["dialyzer --halt-exit-status"],
      "qa.all": ["qa.format", "qa.credo", "compile --warnings-as-errors", "qa.dialyzer"],
      
      # Development workflow
      "dev.check": ["qa.format", "qa.credo", "compile", "test.smoke"],
      "dev.workflow": ["run scripts/dev_workflow.exs"],
      "dev.benchmark": ["run scripts/benchmark.exs"],
      
      # Architecture validation
      "validate_architecture": ["run -e 'Mix.Tasks.ValidateArchitecture.run([])'"],
      
      # CI workflow
      "ci.test": ["qa.all", "test.all", "validate_architecture"],
      
      # Setup
      setup: ["deps.get", "deps.compile", "dialyzer --plt"]
    ]
  end
end

## .formatter.exs
# Code formatting configuration for Foundation layer
[
  inputs: [
    "lib/**/*.{ex,exs}",
    "test/**/*.{ex,exs}",
    "scripts/**/*.{ex,exs}",
    "mix.exs"
  ],
  line_length: 100,
  locals_without_parens: [
    # ExUnit
    assert: 1,
    assert: 2,
    refute: 1,
    refute: 2,
    
    # Custom DSL (if any)
  ]
]

## .credo.exs
# Credo configuration for Foundation layer
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "scripts/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: [
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},

        {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
        {Credo.Check.Design.TagTODO, [exit_status: 2]},
        {Credo.Check.Design.TagFIXME, []},

        {Credo.Check.Readability.AliasOrder, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
        {Credo.Check.Readability.ModuleAttributeNames, []},
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.ModuleNames, []},
        {Credo.Check.Readability.ParenthesesInCondition, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Readability.PredicateFunctionNames, []},
        {Credo.Check.Readability.PreferImplicitTry, []},
        {Credo.Check.Readability.RedundantBlankLines, []},
        {Credo.Check.Readability.Semicolons, []},
        {Credo.Check.Readability.SpaceAfterCommas, []},
        {Credo.Check.Readability.StringSigils, []},
        {Credo.Check.Readability.TrailingBlankLine, []},
        {Credo.Check.Readability.TrailingWhiteSpace, []},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
        {Credo.Check.Readability.VariableNames, []},

        {Credo.Check.Refactor.DoubleBooleanNegation, []},
        {Credo.Check.Refactor.CondStatements, []},
        {Credo.Check.Refactor.CyclomaticComplexity, []},
        {Credo.Check.Refactor.FunctionArity, []},
        {Credo.Check.Refactor.LongQuoteBlocks, []},
        {Credo.Check.Refactor.MapInto, []},
        {Credo.Check.Refactor.MatchInCondition, []},
        {Credo.Check.Refactor.NegatedConditionsInUnless, []},
        {Credo.Check.Refactor.NegatedConditionsWithElse, []},
        {Credo.Check.Refactor.Nesting, []},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.WithClauses, []},

        {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
        {Credo.Check.Warning.BoolOperationOnSameValues, []},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.IoInspect, []},
        {Credo.Check.Warning.LazyLogging, []},
        {Credo.Check.Warning.MapGetUnsafePass, []},
        {Credo.Check.Warning.OperationOnSameValues, []},
        {Credo.Check.Warning.OperationWithConstantResult, []},
        {Credo.Check.Warning.RaiseInsideRescue, []},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedFileOperation, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedPathOperation, []},
        {Credo.Check.Warning.UnusedRegexOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []},
        {Credo.Check.Warning.UnsafeExec, []}
      ]
    }
  ]
}