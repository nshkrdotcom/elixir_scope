# ElixirScope

**Revolutionary AST-based debugging and code intelligence platform for Elixir applications**

<!--
[![Elixir CI](https://github.com/nshkrdotcom/ElixirScope/workflows/Elixir%20CI/badge.svg)](https://github.com/nshkrdotcom/ElixirScope/actions)
[![Coverage Status](https://coveralls.io/repos/github/nshkrdotcom/ElixirScope/badge.svg?branch=main)](https://coveralls.io/github/nshkrdotcom/ElixirScope?branch=main)
[![Hex.pm](https://img.shields.io/hexpm/v/elixir_scope.svg)](https://hex.pm/packages/elixir_scope)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/elixir_scope)
--->

## 🚀 Overview

ElixirScope is a next-generation code analysis and debugging platform that combines static code analysis, runtime correlation, and AI-powered insights to provide unprecedented visibility into Elixir applications. Built with a clean 9-layer architecture, ElixirScope enables developers to understand, debug, and optimize their code like never before.

### ✨ Key Features

- **🧠 AI-Powered Analysis** - LLM integration for intelligent code insights and recommendations
- **🔍 AST-Aware Debugging** - Deep code structure understanding for precise debugging
- **📊 Code Property Graphs** - Advanced graph-based code analysis and visualization
- **⚡ Runtime Correlation** - Connect static analysis with live execution data
- **🏗️ Architectural Intelligence** - Detect patterns, smells, and optimization opportunities
- **🕰️ Time-Travel Debugging** - Step backward through execution history
- **📈 Performance Insights** - Identify bottlenecks and optimization opportunities
- **🔄 Live Code Intelligence** - Real-time analysis as you code

## 🏗️ Architecture

ElixirScope is built with a clean 9-layer architecture that ensures modularity, maintainability, and extensibility:

```
┌─────────────────────────────────────┐
│             Debugger                │ ← Complete debugging interface
├─────────────────────────────────────┤
│           Intelligence              │ ← AI/ML integration  
├─────────────────────────────────────┤
│      Capture          Query         │ ← Runtime correlation & querying
├─────────────────────────────────────┤
│            Analysis                 │ ← Architectural analysis
├─────────────────────────────────────┤
│              CPG                    │ ← Code Property Graph
├─────────────────────────────────────┤
│             Graph                   │ ← Graph algorithms
├─────────────────────────────────────┤
│              AST                    │ ← AST parsing & repository
├─────────────────────────────────────┤
│           Foundation                │ ← Core utilities
└─────────────────────────────────────┘
```

### Layer Overview

| Layer | Purpose | Key Components |
|-------|---------|----------------|
| **Foundation** | Core utilities, events, configuration | Utils, Events, Config, Telemetry |
| **AST** | Code parsing and repository management | Parser, Repository, Data Structures |
| **Graph** | Mathematical graph algorithms | Centrality, Pathfinding, Community Detection |
| **CPG** | Code Property Graph construction | CFG, DFG, Call Graph, Semantics |
| **Analysis** | Architectural analysis and patterns | Smells, Quality, Metrics, Recommendations |
| **Query** | Advanced querying capabilities | Builder, Executor, Extensions |
| **Capture** | Runtime event capture and correlation | Instrumentation, Correlation, Storage |
| **Intelligence** | AI/ML integration | LLM, Features, Models, Insights |
| **Debugger** | Complete debugging interface | Sessions, Breakpoints, Time Travel |

## 🚀 Quick Start

### Installation

Add ElixirScope to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.2.0"}
  ]
end
```

### Basic Usage

```elixir
# Start ElixirScope
{:ok, _} = ElixirScope.start_link()

# Analyze a module
{:ok, analysis} = ElixirScope.analyze_module(MyApp.SomeModule)

# Start a debugging session
{:ok, session_id} = ElixirScope.start_debug_session(MyApp.SomeModule, :some_function, [arg1, arg2])

# Get AI-powered insights
{:ok, insights} = ElixirScope.get_ai_insights(analysis)
```

### Configuration

Configure ElixirScope in your `config.exs`:

```elixir
config :elixir_scope,
  # AI Provider Configuration
  ai_providers: [
    openai: [
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4"
    ],
    anthropic: [
      api_key: System.get_env("ANTHROPIC_API_KEY"),
      model: "claude-3-sonnet"
    ]
  ],
  default_ai_provider: :openai,

  # Analysis Configuration
  analysis: [
    enable_architectural_smells: true,
    enable_performance_analysis: true,
    enable_security_analysis: true
  ],

  # Capture Configuration
  capture: [
    enable_runtime_correlation: true,
    instrumentation: [:phoenix, :ecto, :gen_server]
  ],

  # Debug Configuration
  debugger: [
    enable_time_travel: true,
    enable_ai_assistance: true,
    max_history_size: 1000
  ]
```

## 📖 Usage Examples

### Code Analysis

```elixir
# Basic analysis
{:ok, analysis} = ElixirScope.analyze_file("lib/my_app/user.ex")

# CPG-based analysis
{:ok, cpg} = ElixirScope.build_cpg("lib/my_app/")
{:ok, metrics} = ElixirScope.calculate_metrics(cpg)
{:ok, smells} = ElixirScope.detect_architectural_smells(cpg)

# AI-enhanced analysis
{:ok, insights} = ElixirScope.analyze_with_ai(analysis, """
What are the main architectural issues in this codebase?
Provide specific recommendations for improvement.
""")
```

### Advanced Debugging

```elixir
# Start enhanced debugging session
{:ok, session_id} = ElixirScope.Debugger.start_session(
  MyApp.OrderProcessor, 
  :process_order, 
  [order_data],
  capture_events: true,
  ai_assistance: true,
  time_travel: true
)

# Set intelligent breakpoints
{:ok, breakpoint} = ElixirScope.Debugger.set_intelligent_breakpoint(
  session_id, 
  {MyApp.OrderProcessor, :validate_order, 1}
)

# Step through execution
{:ok, step_result} = ElixirScope.Debugger.step_forward(session_id)

# Get AI debugging assistance
{:ok, suggestion} = ElixirScope.Debugger.ask_ai(
  session_id, 
  "Why is this function taking so long to execute?"
)

# Time travel debugging
{:ok, historical_state} = ElixirScope.Debugger.time_travel(session_id, previous_timestamp)
```

### Query System

```elixir
# Query CPG data
query = ElixirScope.Query.build()
|> ElixirScope.Query.select([:function_name, :complexity, :dependencies])
|> ElixirScope.Query.from(:functions)
|> ElixirScope.Query.where([complexity: {:gt, 10}])
|> ElixirScope.Query.order_by(:complexity, :desc)

{:ok, results} = ElixirScope.Query.execute(query)

# Cross-layer queries
{:ok, hotspots} = ElixirScope.Query.execute("""
  SELECT f.name, f.complexity, p.call_count, p.avg_execution_time
  FROM functions f
  JOIN performance_data p ON f.id = p.function_id
  WHERE p.avg_execution_time > 100
  ORDER BY p.avg_execution_time DESC
""")
```

### Runtime Correlation

```elixir
# Start runtime capture
{:ok, _} = ElixirScope.Capture.start_capture([MyApp.UserController, MyApp.OrderProcessor])

# Correlate events with code structure
{:ok, correlation} = ElixirScope.Capture.correlate_events_with_ast(captured_events)

# Build execution timeline
{:ok, timeline} = ElixirScope.Capture.build_timeline(correlation)

# Analyze performance patterns
{:ok, patterns} = ElixirScope.Analysis.analyze_performance_patterns(timeline)
```

## 🧪 Testing

ElixirScope includes a comprehensive enterprise test suite:

```bash
# Run unit tests
mix test.unit

# Run integration tests
mix test.integration

# Run end-to-end tests
mix test.end_to_end

# Run performance tests
mix test.performance

# Run all tests
mix test.all

# Run CI-friendly test suite
mix test.ci

# Run quality gate
./test/quality_gate.sh
```

### Test Categories

- **Unit Tests** (`test/unit/`) - Fast, isolated layer-specific tests
- **Functional Tests** (`test/functional/`) - Feature-level testing
- **Integration Tests** (`test/integration/`) - Cross-layer integration
- **End-to-End Tests** (`test/end_to_end/`) - Complete workflow testing
- **Performance Tests** (`test/performance/`) - Benchmarks and performance validation
- **Property Tests** (`test/property/`) - Property-based testing
- **Contract Tests** (`test/contract/`) - API contract validation

## 🏗️ Development

### Prerequisites

- Elixir 1.15+ and OTP 26+
- PostgreSQL (for persistent storage)
- Redis (for caching)
- Node.js 18+ (for web interface)

### Setup

```bash
# Clone the repository
git clone https://github.com/nshkrdotcom/ElixirScope.git
cd ElixirScope

# Install dependencies
mix deps.get

# Set up the database
mix ecto.setup

# Run tests
mix test

# Start the application
mix phx.server
```

### Development Workflow

```bash
# Create feature branch
git checkout -b feature/amazing-new-feature

# Make changes and test
mix test.unit
mix test.integration

# Check code quality
mix credo --strict
mix dialyzer

# Run quality gate
./test/quality_gate.sh

# Create pull request
git push origin feature/amazing-new-feature
```

### Architecture Guidelines

1. **Layer Dependencies**: Each layer only depends on lower layers
2. **Clean APIs**: Well-defined interfaces between layers
3. **Testing**: Comprehensive test coverage at all levels
4. **Documentation**: Clear documentation for all public APIs
5. **Performance**: Efficient algorithms and memory management

## 🔧 API Reference

### Core APIs

#### ElixirScope.analyze_module/2

Performs comprehensive analysis of an Elixir module.

```elixir
@spec analyze_module(module(), keyword()) :: {:ok, Analysis.t()} | {:error, term()}
```

**Options:**
- `:include_cpg` - Include Code Property Graph analysis (default: `true`)
- `:include_metrics` - Include complexity metrics (default: `true`)
- `:include_smells` - Include architectural smell detection (default: `true`)
- `:ai_analysis` - Include AI-powered insights (default: `false`)

#### ElixirScope.start_debug_session/4

Starts an enhanced debugging session.

```elixir
@spec start_debug_session(module(), atom(), [term()], keyword()) :: 
  {:ok, session_id()} | {:error, term()}
```

**Options:**
- `:capture_events` - Enable runtime event capture (default: `true`)
- `:ai_assistance` - Enable AI debugging assistance (default: `false`)
- `:time_travel` - Enable time-travel debugging (default: `true`)
- `:visualization` - Visualization mode (default: `:cinema`)

#### ElixirScope.Query.execute/2

Executes advanced queries across all data sources.

```elixir
@spec execute(Query.t() | String.t(), keyword()) :: {:ok, [term()]} | {:error, term()}
```

### Layer-Specific APIs

Each layer provides its own comprehensive API. See the [full API documentation](https://hexdocs.pm/elixir_scope) for details.

## 🤖 AI Integration

ElixirScope integrates with multiple AI providers for intelligent code analysis:

### Supported Providers

- **OpenAI** (GPT-4, GPT-3.5-turbo)
- **Anthropic** (Claude-3-sonnet, Claude-3-haiku)
- **Google** (Gemini Pro)
- **Custom Providers** (implement the provider behavior)

### AI Features

- **Code Analysis** - Intelligent code review and recommendations
- **Debug Assistance** - AI-powered debugging suggestions
- **Pattern Recognition** - Automated detection of code patterns and anti-patterns
- **Performance Optimization** - AI-driven performance improvement suggestions
- **Documentation Generation** - Automated documentation and code comments

### Example AI Analysis

```elixir
{:ok, insights} = ElixirScope.analyze_with_ai(code, """
Analyze this Elixir code for:
1. Potential performance bottlenecks
2. Security vulnerabilities
3. Code maintainability issues
4. Suggestions for improvement

Focus on Elixir-specific best practices and OTP design patterns.
""")

# insights.recommendations contains structured suggestions
# insights.confidence_score indicates AI confidence level
# insights.explanations provides detailed reasoning
```

## 📊 Performance & Benchmarks

ElixirScope is designed for performance and can handle large codebases efficiently:

### Benchmark Results

- **AST Parsing**: ~1000 modules/second
- **CPG Construction**: ~500 modules/second  
- **Graph Analysis**: ~100k nodes/second
- **Memory Usage**: ~10MB per 1000 modules
- **Query Performance**: Sub-second for most queries

### Optimization Features

- **Incremental Analysis** - Only re-analyze changed code
- **Memory Management** - Intelligent caching and cleanup
- **Parallel Processing** - Multi-core utilization
- **Lazy Loading** - Load data on demand
- **Query Optimization** - Efficient query execution

## 🔐 Security

ElixirScope takes security seriously:

### Security Features

- **Secure AI Integration** - API keys encrypted at rest
- **Sandboxed Code Execution** - Safe code analysis
- **Access Control** - Role-based permissions
- **Audit Logging** - Comprehensive activity logs
- **Data Privacy** - Optional local-only mode

### Security Best Practices

1. Store API keys securely using environment variables
2. Use local-only mode for sensitive codebases
3. Regularly update dependencies
4. Enable audit logging in production
5. Follow the principle of least privilege

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Ways to Contribute

- **Bug Reports** - Report issues via GitHub Issues
- **Feature Requests** - Suggest new features
- **Code Contributions** - Submit pull requests
- **Documentation** - Improve docs and examples
- **Testing** - Add test cases and scenarios

### Development Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run the quality gate
6. Submit a pull request

## 📄 License

ElixirScope is released under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- The Elixir community for building an amazing language and ecosystem
- Contributors who have helped shape ElixirScope
- The OTP team for creating the foundation we build upon
- AI research community for advancing code intelligence

## 📞 Support

- **Documentation**: [https://hexdocs.pm/elixir_scope](https://hexdocs.pm/elixir_scope)
- **Issues**: [GitHub Issues](https://github.com/nshkrdotcom/ElixirScope/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nshkrdotcom/ElixirScope/discussions)
- **Email**: support@elixirscope.dev

## 🗺️ Roadmap

### Version 0.3.0 (Q2 2025)
- [ ] Enhanced AI model integration
- [ ] Real-time collaborative debugging
- [ ] Advanced visualization engine
- [ ] Distributed system analysis

### Version 0.4.0 (Q3 2025)
- [ ] Machine learning code prediction
- [ ] Automated refactoring suggestions
- [ ] Integration with popular IDEs
- [ ] Cloud-based analysis platform

### Version 1.0.0 (Q4 2025)
- [ ] Production-ready stability
- [ ] Enterprise features
- [ ] Comprehensive plugin system
- [ ] Advanced reporting dashboard

---

**Built with ❤️ by the ElixirScope team**

*ElixirScope - Illuminating the path to better Elixir code*
