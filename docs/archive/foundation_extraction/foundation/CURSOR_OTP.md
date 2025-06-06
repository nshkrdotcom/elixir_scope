# CURSOR_OTP.md: OTP Architecture Design for AI-Assisted Development

## Executive Summary

This document addresses a critical architectural conundrum discovered during AI-assisted development of the ElixirScope Foundation layer. Current fixes are symptomatic rather than systematic, revealing the need for proper BEAM/OTP engineering process and supervision tree design.

## The Conundrum

### Current Situation
- **AI Approach**: Tactical fixes to individual test failures
- **Symptom**: Tests pass in isolation but fail under concurrent access
- **Root Cause**: Fundamental violation of OTP principles and supervision tree design
- **Evidence**: Tests fail when both human engineer and AI agent run simultaneously

### Core Problem Statement
The current approach treats GenServer processes as isolated units rather than designing a proper OTP supervision tree with fault tolerance, process isolation, and proper lifecycle management. This violates the "let it crash" philosophy and creates hidden concurrency bugs.

### Architectural Debt
1. **Process Registration**: Ad-hoc naming schemes instead of proper supervision trees
2. **State Management**: Manual state reset instead of process restart strategies  
3. **Error Handling**: Defensive programming instead of "let it crash"
4. **Test Isolation**: Process-level patches instead of supervisor-managed isolation
5. **Concurrency**: Race condition fixes instead of proper process boundaries

## Required OTP Engineering Process

### Phase 1: Supervision Tree Design
**Objective**: Design proper OTP supervision hierarchy for Foundation layer

**Key Decisions Needed**:
- Supervisor restart strategies (`:one_for_one`, `:one_for_all`, `:rest_for_one`)
- Child specification and startup dependencies
- Process registration strategies (local vs global vs registry)
- Fault tolerance boundaries and isolation levels

**Critical Questions**:
1. What constitutes a fault boundary in the Foundation layer?
2. Which processes must restart together vs independently?
3. How should test isolation be achieved through supervision?
4. What's the proper dependency order for Foundation services?

### Phase 2: Process Lifecycle Management
**Objective**: Implement proper OTP process lifecycle with restart strategies

**Key Components**:
- Proper `child_spec/1` implementations
- Dynamic supervisor for test isolation
- Process monitoring and health checks
- Graceful shutdown sequences

### Phase 3: Fault Tolerance Design
**Objective**: Embrace "let it crash" philosophy with proper error boundaries

**Key Principles**:
- Fail fast instead of defensive programming
- Supervisor-managed restarts instead of manual recovery
- Process isolation instead of shared state management
- Circuit breakers for external dependencies

## Ideal Documentation Structure for Senior BEAM/OTP Engineer

### 1. Foundation Architecture Specification (`FOUNDATION_OTP_SPEC.md`)

```markdown
# Foundation Layer OTP Architecture Specification

## Supervision Tree Design
- Root supervisor: `ElixirScope.Foundation.Supervisor`
- Service supervisors for each major component
- Test isolation through dynamic supervision

## Process Registry Strategy
- Local registration for production
- Dynamic registration for test isolation
- Registry-based naming for complex scenarios

## Fault Tolerance Boundaries
- Service-level isolation (ConfigServer, EventStore, TelemetryService)
- Cross-service dependencies and restart cascades
- Circuit breaker patterns for external calls

## Restart Strategies
- Individual service failures: `:one_for_one`
- Dependency-related failures: `:rest_for_one`
- Critical system failures: `:one_for_all`
```

### 2. OTP Design Patterns Guide (`OTP_PATTERNS.md`)

```markdown
# OTP Design Patterns for ElixirScope

## Supervision Patterns
- How to design proper supervision trees
- When to use different restart strategies
- Child specification best practices

## GenServer Patterns
- State management without manual reset
- Process lifecycle hooks
- Error handling and restart policies

## Test Isolation Patterns
- Dynamic supervisor usage for tests
- Process registry strategies
- State isolation through process boundaries
```

### 3. Cursor Prompting Strategy (`CURSOR_OTP_PROMPTS.md`)

```markdown
# Cursor Prompting Strategy for OTP Development

## Context Setting Prompts
"Design this as a proper OTP supervision tree following BEAM principles..."

## Architecture Review Prompts
"Review this GenServer for OTP compliance, focusing on supervision tree integration..."

## Testing Strategy Prompts
"Design test isolation using OTP supervision rather than manual process management..."

## Error Handling Prompts
"Apply 'let it crash' philosophy - identify where defensive programming should be removed..."
```

### 4. OTP Implementation Checklist (`OTP_CHECKLIST.md`)

```markdown
# OTP Implementation Checklist

## Supervision Tree
- [ ] Root supervisor defined with proper child specs
- [ ] Service supervisors for major components
- [ ] Dynamic supervisor for test isolation
- [ ] Proper restart strategies configured

## GenServer Implementation
- [ ] Proper `child_spec/1` implementations
- [ ] Supervision tree integration
- [ ] Error handling follows "let it crash"
- [ ] State management through restarts, not manual reset

## Test Architecture
- [ ] Test isolation through supervisaion
- [ ] No manual process management in tests
- [ ] Proper setup/teardown using OTP lifecycle
- [ ] Concurrent test safety through process boundaries
```

## Specific Architectural Issues to Address

### 1. Process Registration Anti-Pattern
**Current**: Dynamic naming with process dictionary hacks
**Should Be**: Proper supervision tree with registry-based naming or scoped supervisors

### 2. State Management Anti-Pattern  
**Current**: Manual `reset_state/0` functions for test cleanup
**Should Be**: Process restart-based isolation through supervisors

### 3. Error Handling Anti-Pattern
**Current**: Defensive programming with extensive error checking
**Should Be**: "Let it crash" with supervisor-managed recovery

### 4. Test Isolation Anti-Pattern
**Current**: Manual process lifecycle management in `TestProcessManager`
**Should Be**: Dynamic supervisor with isolated supervision trees per test

### 5. Concurrency Anti-Pattern
**Current**: Race condition fixes and synchronization patches  
**Should Be**: Proper process boundaries and message passing design

## Recommended Cursor Workflow for OTP Engineer

### Initial Architecture Design
1. **Prompt**: "Design a proper OTP supervision tree for the Foundation layer with ConfigServer, EventStore, and TelemetryService as supervised children"
2. **Focus**: Supervision hierarchy, restart strategies, dependencies
3. **Output**: Complete supervision tree specification

### Service Implementation
1. **Prompt**: "Implement ConfigServer as a proper OTP GenServer with child_spec and supervision integration"
2. **Focus**: OTP compliance, lifecycle management, error boundaries
3. **Output**: Production-ready GenServer implementation

### Test Architecture
1. **Prompt**: "Design test isolation using dynamic supervisors instead of manual process management"
2. **Focus**: OTP-native test patterns, process isolation
3. **Output**: Supervision-based test framework

### Error Handling Review
1. **Prompt**: "Review error handling for 'let it crash' compliance - identify defensive programming to remove"
2. **Focus**: Fault tolerance, supervisor responsibilities
3. **Output**: Simplified, crash-tolerant implementation

## Success Criteria

### Technical Measures
- [ ] All tests pass under concurrent execution
- [ ] No manual process lifecycle management
- [ ] Proper supervision tree hierarchy
- [ ] "Let it crash" error handling throughout

### Architectural Measures  
- [ ] Clear fault tolerance boundaries
- [ ] Supervisor-managed restarts instead of manual recovery
- [ ] Process isolation through OTP design
- [ ] Registry-based or supervised naming strategies

### Enterprise Readiness
- [ ] Robust under high concurrency
- [ ] Graceful degradation patterns
- [ ] Observable supervision tree health
- [ ] Proper OTP application structure

## Conclusion

The current tactical approach has revealed the need for fundamental OTP architecture redesign. This document provides the framework for a senior BEAM/OTP engineer to design proper supervision trees, implement fault tolerance, and create robust concurrent systems that embrace OTP principles rather than fighting them.

The goal is enterprise-grade infrastructure that naturally handles concurrency, failures, and scaling through proper OTP design rather than defensive programming patches. 