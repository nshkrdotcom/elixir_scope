ElixirScope is an **AST-based debugging and code intelligence platform** for Elixir applications. It provides visibility into Elixir applications by combining **static code analysis, runtime correlation, and AI-powered insights**.

---

### Key Features

* **AI-Powered Analysis**: Uses Large Language Model (LLM) integration for intelligent code insights and recommendations.
* **AST-Aware Debugging**: Offers deep code structure understanding for precise debugging.
* **Code Property Graphs (CPG)**: Enables advanced graph-based code analysis and visualization.
* **Runtime Correlation**: Connects static analysis with live execution data.
* **Architectural Intelligence**: Detects code patterns, smells, and optimization opportunities.
* **Time-Travel Debugging**: Allows stepping backward through execution history.
* **Performance Insights**: Identifies bottlenecks and optimization opportunities.
* **Live Code Intelligence**: Provides real-time analysis during coding.

---

### Architecture

ElixirScope uses a **9-layer architecture** for modularity, maintainability, and extensibility:

1.  **Debugger**: Complete debugging interface.
2.  **Intelligence**: AI/ML integration.
3.  **Capture**: Runtime correlation and querying.
4.  **Analysis**: Architectural analysis.
5.  **CPG**: Code Property Graph.
6.  **Graph**: Graph algorithms.
7.  **AST**: AST parsing and repository.
8.  **Foundation**: Core utilities.

---

### Installation and Usage

To install ElixirScope, add `{:elixir_scope, "~> 0.2.0"}` to your `mix.exs` dependencies.

**Basic Usage:**

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

**Configuration:**

Configure ElixirScope in your `config.exs` to set up AI providers, analysis options, capture settings, and debugger behavior.

---

### AI Integration

ElixirScope integrates with AI providers like **OpenAI, Anthropic, and Google (Gemini Pro)**. It uses AI for **code analysis, debugging assistance, pattern recognition, performance optimization, and documentation generation**.
