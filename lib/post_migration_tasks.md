# Post-Migration Tasks

## Immediate Tasks

### 1. Update Module References
Search and replace old module references in the codebase:

```bash
# Example replacements needed:
find . -name "*.ex" -exec sed -i 's/ElixirScope\.ASTRepository\.Enhanced\.CPGMath/ElixirScope.Graph.Algorithms/g' {} \;
find . -name "*.ex" -exec sed -i 's/ElixirScope\.ASTRepository\.Enhanced\.CPGBuilder/ElixirScope.CPG.Builder/g' {} \;
find . -name "*.ex" -exec sed -i 's/ElixirScope\.ASTRepository\.Enhanced/ElixirScope.AST.Enhanced/g' {} \;
```

### 2. Extract Graph Algorithms
The graph algorithms were embedded in CPG builder files. Extract them:

1. Review `cpg/builder/core/core.ex` for graph algorithm implementations
2. Extract pure mathematical operations to `graph/algorithms/`
3. Update CPG builder to use the extracted graph algorithms

### 3. Implement Missing Modules
Create implementations for modules that were expected but not found:

- `cpg/semantics.ex` (if semantic analysis was embedded elsewhere)
- `cpg/optimization.ex` (if optimization was embedded elsewhere)
- Any other missing semantic or optimization components

### 4. Update Import Statements
Update all `alias`, `import`, and `use` statements to reference new module locations.

### 5. Test Compilation
```bash
mix compile
```

Fix any compilation errors by updating module references.

## Verification Tasks

### 1. Check All Files Moved
Verify that `../elixir_scope_old/` is now empty or contains only expected remnants.

### 2. Validate Module Structure
Ensure all modules in each layer follow the proper naming convention:
- Foundation: `ElixirScope.Foundation.*`
- AST: `ElixirScope.AST.*`
- Graph: `ElixirScope.Graph.*`
- CPG: `ElixirScope.CPG.*`
- etc.

### 3. Test Layer Dependencies
Verify that layers only depend on lower layers:
```
Debugger → Intelligence → Capture/Query → Analysis → CPG → Graph → AST → Foundation
```

## Refactoring Tasks

### 1. Extract Graph Algorithms
Priority: High
- Extract centrality calculations from CPG code
- Extract pathfinding algorithms
- Extract community detection logic
- Extract connectivity analysis

### 2. Implement Analysis Layer
Priority: Medium
- Move pattern detection logic to analysis layer
- Implement architectural smell detection
- Create quality assessment modules

### 3. Enhance Intelligence Layer
Priority: Medium
- Implement feature extraction
- Create ML model interfaces
- Enhance AI integration

### 4. Complete Debugger Layer
Priority: Low
- Implement core debugging interface
- Create session management
- Integrate with capture layer

## Notes

- Some files may have been embedded in other modules and need extraction
- Module namespaces need updating throughout the codebase
- Integration tests should be run after module updates
- Consider creating aliases for backward compatibility during transition
