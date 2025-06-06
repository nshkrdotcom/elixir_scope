# Documentation Cleanup Plan

**Status:** Ready for execution  
**Priority:** High - Clean organization needed before implementation

## Immediate Actions Required

### 1. **Archive Outdated Content**
```bash
# Move to archive/legacy/
docs/docs20250602/          # Dated foundation docs - superseded
docs/docu/                  # General docs - consolidate relevant parts
docs/foundation/            # Foundation layer docs - mostly irrelevant now
docs/extract/               # Extraction planning docs - obsolete
docs/docs_local/            # Local development notes - archive
docs/docs_module2_ast/      # Duplicate AST content
```

### 2. **Consolidate Reference Implementation**
```bash
# Rename and organize the real implementation
docs/code/libfuture/elixir_scope/ → docs/reference_implementation/
```

### 3. **Update AST Documentation Structure** 
Current `docs/ast/` contains monolith-era PRDs that need refactoring:
- `AST_PRD.md` - Update for unified package architecture
- `AST_TECH_SPEC.md` - Remove Foundation duplication, focus on AST-specific features  
- `AST_FOUNDATION_API_ENHANCED.md` - Obsolete (Foundation now external)
- `MIGRATION_*` files - Update for new structure

### 4. **Create Clean Documentation Structure**
```
docs/
├── README.md                     # Overview and navigation
├── ARCHITECTURE.md              # High-level architecture (from claudeCodeArchPlan.md)
├── implementation/
│   ├── AST_IMPLEMENTATION.md    # Refined from existing AST docs
│   ├── GRAPH_IMPLEMENTATION.md  
│   ├── CPG_IMPLEMENTATION.md
│   └── [other layers]
├── reference_implementation/     # Moved from docs/code/libfuture/elixir_scope/
│   ├── ast/
│   ├── graph/
│   └── [other layers]
└── archive/                     # All outdated content
    ├── legacy_monolith/
    ├── foundation_extraction/
    └── dated_docs/
```

### 5. **Delete Obsolete Content**
- `docs/FOUNDATION_OTP_IMPLEMENT_NOW/` - Foundation complete, irrelevant
- `docs/infrastructure/` - Infrastructure patterns now in Foundation
- Duplicate files across directories
- `docs/ast_prompts/` - Implementation guidance, no longer needed

## Refactoring Priority

### **High Priority** (Do First)
1. Move reference implementation to clear location
2. Archive all Foundation-related documentation  
3. Update AST PRD/Tech Spec for unified architecture

### **Medium Priority** (Do Second)  
1. Consolidate scattered implementation notes
2. Create clean layer-by-layer implementation guides
3. Update CLAUDE.md with new structure

### **Low Priority** (Do Later)
1. Archive development history
2. Clean up test documentation
3. Organize benchmarking data

## Post-Cleanup Next Steps

**Recommendation: Proceed directly to implementation after cleanup**

Rationale:
- Architecture plan is solid and comprehensive
- Reference implementation provides clear guidance  
- Further documentation would delay actual progress
- Learning-by-doing will reveal real implementation needs

**Implementation Strategy:**
1. Start with Graph layer (lowest complexity, clear boundaries)
2. Move to AST layer (central hub, highest value)
3. Build incrementally with continuous validation

The cleanup should take 1-2 days, then proceed immediately to Graph layer implementation.