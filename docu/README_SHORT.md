# ElixirScope

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
