# ElixirScope Documentation

**Version:** 2.0  
**Date:** December 6, 2025  
**Status:** Unified Package Architecture

## Overview

ElixirScope is a comprehensive AST-based debugging and code intelligence platform for Elixir applications. This documentation reflects the **unified package architecture** where all 8 layers are contained within a single `elixir_scope` package, with Foundation as an external hex dependency.

## Project Structure

```
elixir_scope/                           # Unified package
├── Foundation (external dependency)    # Infrastructure services
├── AST Layer                          # Static code analysis  
├── Graph Layer                        # Mathematical algorithms
├── CPG Layer                          # Code Property Graph
├── Analysis Layer                     # Pattern detection
├── Capture Layer                      # Runtime instrumentation
├── Query Layer                        # Query engine
├── Intelligence Layer                 # AI/ML integration  
└── Debugger Layer                     # Debugging interface
```

## Documentation Organization

### 📋 Planning Documents
- [`claudeCodeArchPlan.md`](../claudeCodeArchPlan.md) - **Complete architecture plan and implementation strategy**
- [`CLEANUP.md`](CLEANUP.md) - Documentation cleanup strategy (completed)

### 🛠️ Implementation Guides
- [`implementation/AST_IMPLEMENTATION_GUIDE.md`](implementation/AST_IMPLEMENTATION_GUIDE.md) - **AST Layer implementation (Core)**
- [`implementation/GRAPH_IMPLEMENTATION_GUIDE.md`](implementation/GRAPH_IMPLEMENTATION_GUIDE.md) - **Graph Layer hybrid libgraph approach (Start Here)**
- Additional layer guides to be created as needed

### 📚 Reference Implementation
- [`reference_implementation/`](reference_implementation/) - **Complete working implementation from original monolith**
  - `ast/` - AST layer reference code (70 files, 16k LOC)
  - `graph/` - Graph algorithms reference (11 files, 506 LOC) - **NOTE: Using libgraph + custom extensions instead**  
  - `cpg/` - CPG construction reference (80 files, 14k LOC)
  - `capture/` - Runtime capture reference (50 files, 10.7k LOC)
  - `intelligence/` - AI integration reference (22 files, 5.4k LOC)
  - `analysis/` - Analysis patterns reference (38 files, 3.6k LOC)
  - `query/` - Query engine reference (13 files, 1.8k LOC)
  - `debugger/` - Debugger interface reference (18 files, 1.6k LOC)

### 🎯 Layer-Specific Documentation
- [`ast/`](ast/) - AST Layer PRDs and technical specs (legacy - needs update)
- [`diags/`](diags/) - Diagnostic and analysis documents
- [`module_docs/`](module_docs/) - API documentation

### 📦 Archive
- [`archive/`](archive/) - Historical documentation organized by purpose
  - `foundation_extraction/` - Foundation layer extraction history
  - `legacy_monolith/` - Original monolith architecture docs
  - `dated_docs/` - Time-stamped development documentation
  - `development_history/` - Development notes and evolution

## Quick Start for Implementation

### Phase 1: Foundation Integration (Complete ✅)
Foundation layer is extracted to external hex dependency `foundation ~> 0.1.0`

### Phase 2: Graph Layer (Week 2) - HYBRID APPROACH
**Start here** - Using libgraph + custom extensions for faster implementation
```bash
# Implementation target
lib/elixir_scope/graph/

# libgraph integration + custom code analysis algorithms
# 70% faster implementation vs. building from scratch
# Reference: docs/implementation/GRAPH_IMPLEMENTATION_GUIDE.md
```

### Phase 3: AST Layer (Weeks 3-4)  
**Core functionality** - Central data hub for all other layers
```bash
# Implementation target
lib/elixir_scope/ast/

# Reference code
docs/reference_implementation/ast/
```

### Phase 4: Remaining Layers (Weeks 5-16)
Build incrementally: CPG → Analysis → [Capture, Query] → Intelligence → Debugger

## Architecture Decisions

### ✅ Unified Package Benefits
- **Single dependency**: `{:elixir_scope, "~> 0.1.0"}`
- **Atomic deployments**: All layers versioned together
- **Direct integration**: Function calls vs. message passing
- **Shared memory**: Efficient ETS table and cache sharing
- **Simplified testing**: No external dependency coordination

### ✅ Foundation as External Dependency
- **Reusable infrastructure**: Available to other Elixir projects
- **Stable base**: Infrastructure changes rarely
- **Clear separation**: Domain logic vs. infrastructure concerns
- **Production ready**: 168 tests, comprehensive OTP compliance

### 📊 Complexity Analysis
| Layer | Files | LOC | Complexity | Priority |
|-------|-------|-----|------------|----------|
| AST | 70 | 16,383 | **HIGHEST** | Core (Phase 3) |
| CPG | 80 | 14,430 | **HIGHEST** | Phase 4 |
| Capture | 50 | 10,727 | **HIGH** | Phase 4 |
| Intelligence | 22 | 5,396 | **MEDIUM-HIGH** | Phase 4 |
| Analysis | 38 | 3,638 | **MEDIUM** | Phase 4 |
| Query | 13 | 1,800 | **MEDIUM** | Phase 4 |
| Debugger | 18 | 1,589 | **MEDIUM** | Phase 4 |
| Graph | 11 | 506 | **LOW** | Start (Phase 2) |

## Development Workflow

### Current Status
- ✅ Foundation layer complete and extracted
- ✅ Architecture plan finalized  
- ✅ Documentation organized
- ✅ Reference implementation preserved
- 🚧 Ready to begin Graph layer implementation

### Implementation Strategy
1. **Graph Layer** (1 week) - Prove architecture, minimal complexity
2. **AST Layer** (2 weeks) - Core functionality, highest value
3. **Iterative builds** - Add layers incrementally with validation
4. **Integration testing** - Validate cross-layer communication
5. **Performance optimization** - Memory management, query performance

### Development Commands
```bash
# Setup (from main README)
mix deps.get && mix compile

# Testing
mix test.smoke          # Foundation integration
mix test.unit           # Layer-specific tests
mix test.integration    # Cross-layer tests

# Quality checks
mix dev.check           # Format, Credo, compile, smoke tests
```

## Key Resources

### Primary References
1. **Architecture Plan**: [`claudeCodeArchPlan.md`](../claudeCodeArchPlan.md) - Complete strategy
2. **Reference Code**: [`reference_implementation/`](reference_implementation/) - Working implementation
3. **Foundation API**: [`README_FOUNDATION.md`](README_FOUNDATION.md) - Foundation layer usage

### Implementation Support
- **Layer Guides**: Step-by-step implementation instructions
- **Test Patterns**: Testing strategies for each layer
- **Integration Examples**: Cross-layer communication patterns
- **Performance Targets**: Benchmarks and optimization guidelines

---

This documentation structure provides comprehensive support for implementing the unified ElixirScope package while preserving historical context and providing clear implementation guidance.