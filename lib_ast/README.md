The filenames relevant to Layer 2 (AST PARSING & REPOSITORY) are:

**AST Parsing & Transformation:**
*   `ast/enhanced_transformer.ex`
*   `ast/injector_helpers.ex`
*   `ast/transformer.ex`
*   `ast_repository/parser.ex`
*   `ast_repository/instrumentation_mapper.ex`
*   `compile_time/orchestrator.ex`
*   `compiler/mix_task.ex`

**AST Repository (Storage, Data Structures, Management, Querying):**
*   `ast_repository/repository.ex`
*   `ast_repository/enhanced_repository.ex`
*   `ast_repository/enhanced/repository.ex`

    *   **Data Structures (defining what the repository stores):**
        *   `ast_repository/module_data.ex`
        *   `ast_repository/module_data/ast_analyzer.ex`
        *   `ast_repository/module_data/attribute_extractor.ex`
        *   `ast_repository/module_data/complexity_calculator.ex`
        *   `ast_repository/module_data/dependency_extractor.ex`
        *   `ast_repository/module_data/pattern_detector.ex`
        *   `ast_repository/function_data.ex`
        *   `ast_repository/enhanced_module_data.ex`
        *   `ast_repository/enhanced_function_data.ex`
        *   `ast_repository/enhanced/variable_data.ex`
        *   `ast_repository/enhanced/shared_data_structures.ex`
        *   `ast_repository/enhanced/supporting_structures.ex`
        *   `ast_repository/enhanced/complexity_metrics.ex`
        *   `ast_repository/enhanced/cfg_data.ex`
        *   `ast_repository/enhanced/dfg_data.ex`
        *   `ast_repository/enhanced/cpg_data.ex`

    *   **Project Population (getting data into the repository):**
        *   `ast_repository/enhanced/project_populator.ex`
        *   `ast_repository/enhanced/project_populator/ast_extractor.ex`
        *   `ast_repository/enhanced/project_populator/complexity_analyzer.ex`
        *   `ast_repository/enhanced/project_populator/dependency_analyzer.ex`
        *   `ast_repository/enhanced/project_populator/file_discovery.ex`
        *   `ast_repository/enhanced/project_populator/file_parser.ex`
        *   `ast_repository/enhanced/project_populator/module_analyzer.ex`
        *   `ast_repository/enhanced/project_populator/optimization_hints.ex`
        *   `ast_repository/enhanced/project_populator/performance_metrics.ex`
        *   `ast_repository/enhanced/project_populator/quality_analyzer.ex`
        *   `ast_repository/enhanced/project_populator/security_analyzer.ex`

    *   **Repository Management:**
        *   `ast_repository/memory_manager.ex` (if it's a facade file, otherwise the directory)
        *   `ast_repository/memory_manager/cache_manager.ex`
        *   `ast_repository/memory_manager/cleaner.ex`
        *   `ast_repository/memory_manager/compressor.ex`
        *   `ast_repository/memory_manager/config.ex`
        *   `ast_repository/memory_manager/monitor.ex`
        *   `ast_repository/memory_manager/pressure_handler.ex`
        *   `ast_repository/memory_manager/supervisor.ex`
        *   `ast_repository/memory_manager/test_runner.ex`
        *   `ast_repository/performance_optimizer.ex` (if it's a facade file, otherwise the directory)
        *   `ast_repository/performance_optimizer/batch_processor.ex`
        *   `ast_repository/performance_optimizer/cache_manager.ex`
        *   `ast_repository/performance_optimizer/lazy_loader.ex`
        *   `ast_repository/performance_optimizer/optimization_scheduler.ex`
        *   `ast_repository/performance_optimizer/statistics_collector.ex`
        *   `ast_repository/enhanced/file_watcher.ex`
        *   `ast_repository/enhanced/synchronizer.ex`

    *   **Repository Querying & Pattern Matching:**
        *   `ast_repository/pattern_matcher.ex` (if it's a facade file, otherwise the directory)
        *   `ast_repository/pattern_matcher/analyzers.ex`
        *   `ast_repository/pattern_matcher/cache.ex`
        *   `ast_repository/pattern_matcher/config.ex`
        *   `ast_repository/pattern_matcher/core.ex`
        *   `ast_repository/pattern_matcher/pattern_library.ex`
        *   `ast_repository/pattern_matcher/pattern_rules.ex`
        *   `ast_repository/pattern_matcher/stats.ex`
        *   `ast_repository/pattern_matcher/types.ex`
        *   `ast_repository/pattern_matcher/validators.ex`
        *   `ast_repository/query_builder.ex` (if it's a facade file, otherwise the directory)
        *   `ast_repository/query_builder/cache.ex`
        *   `ast_repository/query_builder/executor.ex`
        *   `ast_repository/query_builder/normalizer.ex`
        *   `ast_repository/query_builder/optimizer.ex`
        *   `ast_repository/query_builder/supervisor.ex`
        *   `ast_repository/query_builder/types.ex`
        *   `ast_repository/query_builder/validator.ex`

    *   **Runtime Correlation (Utilizing Repository):**
        *   `ast_repository/runtime_correlator.ex` (if it's a facade file, otherwise the directory)
        *   `ast_repository/runtime_correlator/breakpoint_manager.ex`
        *   `ast_repository/runtime_correlator/cache_manager.ex`
        *   `ast_repository/runtime_correlator/config.ex`
        *   `ast_repository/runtime_correlator/context_builder.ex`
        *   `ast_repository/runtime_correlator/event_correlator.ex`
        *   `ast_repository/runtime_correlator/trace_builder.ex`
        *   `ast_repository/runtime_correlator/types.ex`
        *   `ast_repository/runtime_correlator/utils.ex`
