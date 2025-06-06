# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ElixirScope is a unified AST-based debugging and code intelligence platform built on a clean 8-layer architecture. It depends on the Foundation hex package (v0.1.0) for enterprise-grade OTP services. The project is organized as a single package containing all 8 layers for optimal integration and deployment.

**Status**: Ready for implementation following the comprehensive architecture plan in `docs/claudeCodeArchPlan.md`

## Development Commands

```bash
# Setup
mix deps.get
mix compile

# Testing (use these specific aliases)
mix test.smoke          # Foundation integration smoke tests
mix test.unit           # Fast unit tests (test/unit)  
mix test.integration    # Cross-layer integration tests (test/integration)
mix test.all            # Complete test suite

# Quality assurance
mix dev.check           # Format check, Credo, compile, smoke tests (required before commits)

# Code quality
mix format
mix credo --strict
```

## Architecture

8-layer architecture built on Foundation dependency:

```
Debugger → Intelligence → [Capture, Query] → Analysis → CPG → Graph → AST → Foundation
```

Each layer module follows the pattern:
- `ElixirScopeCore.LayerName` (e.g., `ElixirScopeCore.AST`)
- All layers currently return `:not_implemented` from their `status/0` function
- Layer supervisors are commented out in `application.ex` until implementation

**Implementation Priority**: Start with Graph layer (lowest complexity), then AST layer (core functionality)

## Foundation Integration

- Foundation services run automatically via the `:foundation` dependency
- Access Foundation services via global names (Foundation.ProcessRegistry, Foundation.ServiceRegistry)
- Foundation provides: ConfigServer, EventStore, TelemetryService, ProcessRegistry, infrastructure protection

## Test Structure

- `test/smoke/` - Foundation integration and health checks (tagged `:smoke`)
- `test/unit/` - Fast unit tests (exclude `:integration` tag)
- `test/integration/` - Cross-layer tests (tagged `:integration`)
- `test/support/` - Test utilities and helpers

## Implementation Resources

- **Architecture Plan**: `docs/claudeCodeArchPlan.md` - Complete implementation strategy
- **Reference Implementation**: `docs/reference_implementation/` - Working code from original monolith
- **Implementation Guides**: `docs/implementation/` - Layer-by-layer implementation instructions  
- **Documentation**: `docs/README.md` - Complete documentation index

## Development Notes

- All 8 layers are skeleton implementations awaiting development
- Use `mix dev.check` before committing (enforced by aliases)
- Project uses Foundation v0.1.0 for enterprise OTP services
- Reference implementation contains 302 files with ~54k LOC to guide development
- Each layer follows a consistent module pattern with `status/0` returning implementation state

## Next Steps

1. **Graph Layer Implementation** (Week 2) - Start here, lowest complexity
2. **AST Layer Implementation** (Weeks 3-4) - Core functionality 
3. **Incremental Layer Development** (Weeks 5-16) - Build remaining layers