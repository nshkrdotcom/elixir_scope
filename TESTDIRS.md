# ElixirScope Test Directory Structure

## Complete Test Organization

```
test/
├── test_helper.exs                    # Global test configuration
├── config/                            # Test configuration files
│   ├── test.exs                      # Test environment config
│   ├── ai_providers.exs              # AI provider test configs
│   └── database.exs                  # Database test configs
│
├── support/                           # Test support utilities
│   ├── helpers.ex                    # General test helpers
│   ├── assertions.ex                 # Custom assertions
│   ├── generators.ex                 # Data generators
│   ├── setup.ex                      # Test environment setup
│   ├── teardown.ex                   # Test cleanup utilities
│   └── test_case.ex                  # Base test case modules
│
├── fixtures/                          # Test data and samples
│   ├── sample_projects/              # Complete sample projects
│   │   ├── simple_module/
│   │   │   ├── lib/simple_module.ex
│   │   │   └── mix.exs
│   │   ├── genserver_app/
│   │   │   ├── lib/
│   │   │   │   ├── worker.ex
│   │   │   │   └── supervisor.ex
│   │   │   └── mix.exs
│   │   ├── phoenix_app/
│   │   │   ├── lib/
│   │   │   │   ├── controllers/user_controller.ex
│   │   │   │   └── live/dashboard_live.ex
│   │   │   └── mix.exs
│   │   ├── otp_system/
│   │   │   ├── lib/
│   │   │   │   ├── application.ex
│   │   │   │   ├── supervisor.ex
│   │   │   │   └── workers/
│   │   │   └── mix.exs
│   │   └── distributed_system/
│   │       ├── lib/
│   │       └── mix.exs
│   ├── ast_data/                     # Pre-generated AST structures
│   │   ├── simple_asts.ex
│   │   ├── complex_asts.ex
│   │   └── genserver_asts.ex
│   ├── cpg_data/                     # Sample CPG structures
│   │   ├── simple_cpgs.ex
│   │   ├── cfg_samples.ex
│   │   └── dfg_samples.ex
│   ├── graph_data/                   # Sample graph structures
│   │   ├── small_graphs.ex
│   │   ├── large_graphs.ex
│   │   └── special_graphs.ex
│   ├── ai_responses/                 # Mock AI responses
│   │   ├── analysis_responses.ex
│   │   ├── code_suggestions.ex
│   │   └── debugging_responses.ex
│   └── runtime_data/                 # Sample runtime events
│       ├── trace_events.ex
│       ├── error_events.ex
│       └── performance_events.ex
│
├── mocks/                             # Mock implementations
│   ├── ai_providers/
│   │   ├── mock_llm_provider.ex
│   │   ├── mock_openai.ex
│   │   ├── mock_anthropic.ex
│   │   ├── mock_gemini.ex
│   │   └── mock_vertex.ex
│   ├── external_services/
│   │   ├── mock_http_client.ex
│   │   ├── mock_file_system.ex
│   │   └── mock_database.ex
│   ├── instrumentation/
│   │   ├── mock_tracer.ex
│   │   ├── mock_capture.ex
│   │   └── mock_correlator.ex
│   ├── storage/
│   │   ├── mock_event_store.ex
│   │   └── mock_data_access.ex
│   └── phoenix/
│       ├── mock_conn.ex
│       └── mock_socket.ex
│
├── unit/                              # Unit tests (single module focus)
│   ├── foundation/
│   │   ├── application_test.exs
│   │   ├── config_test.exs
│   │   ├── events_test.exs
│   │   ├── utils_test.exs
│   │   ├── telemetry_test.exs
│   │   ├── core/
│   │   │   ├── supervisor_test.exs
│   │   │   └── registry_test.exs
│   │   └── distributed/
│   │       ├── coordinator_test.exs
│   │       └── node_manager_test.exs
│   ├── ast/
│   │   ├── parser_test.exs
│   │   ├── repository/
│   │   │   ├── core_test.exs
│   │   │   ├── enhanced_test.exs
│   │   │   ├── project_populator_test.exs
│   │   │   ├── synchronizer_test.exs
│   │   │   └── file_watcher_test.exs
│   │   ├── data/
│   │   │   ├── module_data_test.exs
│   │   │   ├── function_data_test.exs
│   │   │   ├── complexity_metrics_test.exs
│   │   │   └── variable_data_test.exs
│   │   ├── memory_manager/
│   │   │   ├── memory_manager_test.exs
│   │   │   ├── monitor_test.exs
│   │   │   ├── cleaner_test.exs
│   │   │   ├── compressor_test.exs
│   │   │   └── cache_manager_test.exs
│   │   ├── pattern_matcher/
│   │   │   ├── pattern_matcher_test.exs
│   │   │   ├── analyzers_test.exs
│   │   │   ├── validators_test.exs
│   │   │   └── cache_test.exs
│   │   ├── query_builder/
│   │   │   ├── builder_test.exs
│   │   │   ├── executor_test.exs
│   │   │   ├── optimizer_test.exs
│   │   │   └── cache_test.exs
│   │   ├── performance_optimizer/
│   │   │   ├── optimizer_test.exs
│   │   │   ├── batch_processor_test.exs
│   │   │   ├── lazy_loader_test.exs
│   │   │   └── statistics_collector_test.exs
│   │   └── compiler/
│   │       ├── transformer_test.exs
│   │       ├── enhanced_transformer_test.exs
│   │       ├── injector_helpers_test.exs
│   │       └── orchestrator_test.exs
│   ├── graph/
│   │   ├── data_structures_test.exs
│   │   ├── utils_test.exs
│   │   ├── math_test.exs
│   │   └── algorithms/
│   │       ├── centrality_test.exs
│   │       ├── pathfinding_test.exs
│   │       ├── connectivity_test.exs
│   │       ├── community_test.exs
│   │       ├── advanced_centrality_test.exs
│   │       ├── temporal_analysis_test.exs
│   │       └── machine_learning_test.exs
│   ├── cpg/
│   │   ├── builder_test.exs
│   │   ├── semantics_test.exs
│   │   ├── optimization_test.exs
│   │   ├── synchronizer_test.exs
│   │   ├── file_watcher_test.exs
│   │   ├── builder/
│   │   │   ├── cfg_test.exs
│   │   │   ├── dfg_test.exs
│   │   │   ├── call_graph_test.exs
│   │   │   └── project_populator_test.exs
│   │   ├── data/
│   │   │   ├── cpg_data_test.exs
│   │   │   ├── cfg_data_test.exs
│   │   │   ├── dfg_data_test.exs
│   │   │   └── shared_structures_test.exs
│   │   └── analysis/
│   │       └── complexity_metrics_test.exs
│   ├── analysis/
│   │   ├── architectural_test.exs
│   │   ├── quality_test.exs
│   │   ├── metrics_test.exs
│   │   ├── recommendations_test.exs
│   │   ├── performance_test.exs
│   │   ├── security_test.exs
│   │   └── patterns/
│   │       ├── smells_test.exs
│   │       ├── design_test.exs
│   │       ├── anti_patterns_test.exs
│   │       ├── elixir_specific_test.exs
│   │       └── otp_patterns_test.exs
│   ├── query/
│   │   ├── builder_test.exs
│   │   ├── executor_test.exs
│   │   ├── optimizer_test.exs
│   │   ├── dsl_test.exs
│   │   ├── cache_test.exs
│   │   └── extensions/
│   │       ├── cpg_test.exs
│   │       ├── analysis_test.exs
│   │       ├── temporal_test.exs
│   │       ├── ml_queries_test.exs
│   │       ├── pattern_queries_test.exs
│   │       └── security_queries_test.exs
│   ├── capture/
│   │   ├── instrumentation_test.exs
│   │   ├── correlation_test.exs
│   │   ├── storage_test.exs
│   │   ├── ingestors_test.exs
│   │   ├── temporal_test.exs
│   │   ├── runtime/
│   │   │   ├── runtime_correlator_test.exs
│   │   │   ├── pipeline_manager_test.exs
│   │   │   ├── event_correlator_test.exs
│   │   │   └── async_writer_test.exs
│   │   └── storage/
│   │       ├── data_access_test.exs
│   │       ├── event_store_test.exs
│   │       ├── ring_buffer_test.exs
│   │       └── temporal_storage_test.exs
│   ├── intelligence/
│   │   ├── features_test.exs
│   │   ├── insights_test.exs
│   │   ├── predictions_test.exs
│   │   ├── orchestration_test.exs
│   │   ├── ai/
│   │   │   ├── code_analyzer_test.exs
│   │   │   ├── ml_test.exs
│   │   │   ├── providers_test.exs
│   │   │   └── llm/
│   │   │       ├── client_test.exs
│   │   │       ├── provider_test.exs
│   │   │       ├── response_test.exs
│   │   │       ├── config_test.exs
│   │   │       └── providers/
│   │   │           ├── mock_test.exs
│   │   │           ├── openai_test.exs
│   │   │           ├── anthropic_test.exs
│   │   │           └── gemini_test.exs
│   │   └── models/
│   │       ├── complexity_predictor_test.exs
│   │       ├── bug_predictor_test.exs
│   │       └── performance_predictor_test.exs
│   └── debugger/
│       ├── core_test.exs
│       ├── interface_test.exs
│       ├── session_test.exs
│       ├── breakpoints_test.exs
│       ├── time_travel_test.exs
│       ├── visualization_test.exs
│       ├── ai_assistant_test.exs
│       └── enhanced/
│           ├── session_test.exs
│           ├── breakpoints_test.exs
│           └── visualization_test.exs
│
├── integration/                       # Cross-component integration tests
│   ├── foundation/
│   │   ├── config_events_integration_test.exs
│   │   ├── telemetry_events_integration_test.exs
│   │   └── distributed_coordination_test.exs
│   ├── ast_graph/
│   │   └── ast_to_graph_pipeline_test.exs
│   ├── ast_cpg/
│   │   ├── ast_to_cpg_pipeline_test.exs
│   │   └── incremental_cpg_update_test.exs
│   ├── cpg_analysis/
│   │   ├── cpg_to_analysis_pipeline_test.exs
│   │   └── pattern_detection_integration_test.exs
│   ├── analysis_intelligence/
│   │   ├── ai_enhanced_analysis_test.exs
│   │   └── ml_insights_integration_test.exs
│   ├── capture_debugger/
│   │   ├── runtime_debug_integration_test.exs
│   │   └── time_travel_correlation_test.exs
│   ├── query_cross_layer/
│   │   ├── multi_layer_queries_test.exs
│   │   └── complex_analysis_queries_test.exs
│   ├── memory_management/
│   │   ├── cross_layer_memory_test.exs
│   │   └── performance_optimization_test.exs
│   └── full_pipeline/
│       ├── code_to_insights_test.exs
│       └── debug_session_pipeline_test.exs
│
├── functional/                        # Feature-level functional tests
│   ├── ast_parsing/
│   │   ├── project_parsing_test.exs
│   │   ├── incremental_parsing_test.exs
│   │   └── error_recovery_test.exs
│   ├── cpg_construction/
│   │   ├── full_cpg_build_test.exs
│   │   ├── incremental_cpg_test.exs
│   │   └── cpg_optimization_test.exs
│   ├── pattern_detection/
│   │   ├── architectural_patterns_test.exs
│   │   ├── anti_patterns_test.exs
│   │   └── custom_patterns_test.exs
│   ├── ai_integration/
│   │   ├── llm_analysis_test.exs
│   │   ├── code_suggestions_test.exs
│   │   └── automated_insights_test.exs
│   ├── debugging_workflow/
│   │   ├── debug_session_test.exs
│   │   ├── breakpoint_management_test.exs
│   │   └── time_travel_debugging_test.exs
│   ├── performance_optimization/
│   │   ├── bottleneck_detection_test.exs
│   │   ├── optimization_suggestions_test.exs
│   │   └── performance_tracking_test.exs
│   ├── query_execution/
│   │   ├── complex_queries_test.exs
│   │   ├── query_optimization_test.exs
│   │   └── result_caching_test.exs
│   ├── runtime_correlation/
│   │   ├── event_correlation_test.exs
│   │   ├── execution_tracking_test.exs
│   │   └── temporal_analysis_test.exs
│   └── code_intelligence/
│       ├── semantic_analysis_test.exs
│       ├── dependency_analysis_test.exs
│       └── quality_assessment_test.exs
│
├── end_to_end/                        # Complete workflow tests
│   ├── phoenix_project_analysis/
│   │   ├── full_phoenix_analysis_test.exs
│   │   ├── live_view_debugging_test.exs
│   │   └── controller_analysis_test.exs
│   ├── genserver_debugging/
│   │   ├── genserver_debug_session_test.exs
│   │   ├── state_tracking_test.exs
│   │   └── callback_analysis_test.exs
│   ├── otp_supervision_analysis/
│   │   ├── supervisor_tree_analysis_test.exs
│   │   ├── fault_tolerance_analysis_test.exs
│   │   └── restart_strategy_test.exs
│   ├── ai_assisted_debugging/
│   │   ├── ai_debug_workflow_test.exs
│   │   ├── intelligent_suggestions_test.exs
│   │   └── automated_problem_detection_test.exs
│   ├── distributed_system_analysis/
│   │   ├── multi_node_analysis_test.exs
│   │   ├── cluster_debugging_test.exs
│   │   └── distributed_tracing_test.exs
│   ├── time_travel_debugging/
│   │   ├── time_travel_workflow_test.exs
│   │   ├── historical_state_test.exs
│   │   └── execution_replay_test.exs
│   └── real_world_projects/
│       ├── existing_project_analysis_test.exs
│       ├── large_codebase_test.exs
│       └── legacy_code_analysis_test.exs
│
├── performance/                       # Performance and scalability tests
│   ├── benchmarks/
│   │   ├── ast_parsing/
│   │   │   ├── parser_benchmarks_test.exs
│   │   │   └── repository_benchmarks_test.exs
│   │   ├── graph_algorithms/
│   │   │   ├── centrality_benchmarks_test.exs
│   │   │   ├── pathfinding_benchmarks_test.exs
│   │   │   └── community_benchmarks_test.exs
│   │   ├── cpg_construction/
│   │   │   ├── cfg_build_benchmarks_test.exs
│   │   │   ├── dfg_build_benchmarks_test.exs
│   │   │   └── full_cpg_benchmarks_test.exs
│   │   ├── query_execution/
│   │   │   ├── simple_query_benchmarks_test.exs
│   │   │   ├── complex_query_benchmarks_test.exs
│   │   │   └── cross_layer_benchmarks_test.exs
│   │   └── ai_integration/
│   │       ├── llm_call_benchmarks_test.exs
│   │       └── analysis_benchmarks_test.exs
│   ├── memory_usage/
│   │   ├── memory_profiling_test.exs
│   │   ├── memory_leak_test.exs
│   │   ├── garbage_collection_test.exs
│   │   └── memory_pressure_test.exs
│   ├── scalability/
│   │   ├── large_project_test.exs
│   │   ├── concurrent_operations_test.exs
│   │   ├── multi_user_test.exs
│   │   └── distributed_scaling_test.exs
│   ├── stress_tests/
│   │   ├── high_load_test.exs
│   │   ├── sustained_operation_test.exs
│   │   └── resource_exhaustion_test.exs
│   └── regression_tests/
│       ├── performance_regression_test.exs
│       └── memory_regression_test.exs
│
├── property/                          # Property-based testing
│   ├── foundation/
│   │   ├── config_properties_test.exs
│   │   ├── event_properties_test.exs
│   │   └── utils_properties_test.exs
│   ├── ast/
│   │   ├── parser_properties_test.exs
│   │   ├── repository_properties_test.exs
│   │   └── data_structure_properties_test.exs
│   ├── graph/
│   │   ├── algorithm_properties_test.exs
│   │   ├── data_structure_properties_test.exs
│   │   └── invariant_properties_test.exs
│   ├── cpg/
│   │   ├── construction_properties_test.exs
│   │   ├── optimization_properties_test.exs
│   │   └── semantic_properties_test.exs
│   ├── analysis/
│   │   ├── pattern_properties_test.exs
│   │   ├── metric_properties_test.exs
│   │   └── quality_properties_test.exs
│   ├── query/
│   │   ├── query_properties_test.exs
│   │   ├── optimization_properties_test.exs
│   │   └── result_properties_test.exs
│   ├── capture/
│   │   ├── correlation_properties_test.exs
│   │   ├── storage_properties_test.exs
│   │   └── temporal_properties_test.exs
│   ├── intelligence/
│   │   ├── prediction_properties_test.exs
│   │   ├── insight_properties_test.exs
│   │   └── ai_properties_test.exs
│   └── debugger/
│       ├── session_properties_test.exs
│       ├── breakpoint_properties_test.exs
│       └── time_travel_properties_test.exs
│
├── contract/                          # API contract tests
│   ├── layer_apis/
│   │   ├── foundation_api_test.exs
│   │   ├── ast_api_test.exs
│   │   ├── graph_api_test.exs
│   │   ├── cpg_api_test.exs
│   │   ├── analysis_api_test.exs
│   │   ├── query_api_test.exs
│   │   ├── capture_api_test.exs
│   │   ├── intelligence_api_test.exs
│   │   └── debugger_api_test.exs
│   ├── external_apis/
│   │   ├── llm_provider_contracts_test.exs
│   │   ├── database_contracts_test.exs
│   │   └── http_client_contracts_test.exs
│   ├── protocol_compliance/
│   │   ├── protocol_implementations_test.exs
│   │   ├── behaviour_implementations_test.exs
│   │   └── otp_compliance_test.exs
│   └── data_contracts/
│       ├── ast_data_contracts_test.exs
│       ├── cpg_data_contracts_test.exs
│       └── event_contracts_test.exs
│
├── smoke/                             # Quick health checks
│   ├── foundation_smoke_test.exs
│   ├── ast_smoke_test.exs
│   ├── graph_smoke_test.exs
│   ├── cpg_smoke_test.exs
│   ├── analysis_smoke_test.exs
│   ├── query_smoke_test.exs
│   ├── capture_smoke_test.exs
│   ├── intelligence_smoke_test.exs
│   ├── debugger_smoke_test.exs
│   └── full_system_smoke_test.exs
│
├── scenarios/                         # Real-world usage scenarios
│   ├── debugging_workflows/
│   │   ├── production_bug_hunt_test.exs
│   │   ├── performance_debugging_test.exs
│   │   └── memory_leak_investigation_test.exs
│   ├── code_analysis_workflows/
│   │   ├── legacy_code_analysis_test.exs
│   │   ├── refactoring_planning_test.exs
│   │   └── architecture_review_test.exs
│   ├── performance_optimization/
│   │   ├── hotspot_identification_test.exs
│   │   ├── bottleneck_analysis_test.exs
│   │   └── optimization_planning_test.exs
│   ├── ai_assisted_development/
│   │   ├── code_review_assistance_test.exs
│   │   ├── bug_prediction_test.exs
│   │   └── optimization_suggestions_test.exs
│   ├── team_collaboration/
│   │   ├── shared_analysis_test.exs
│   │   ├── knowledge_sharing_test.exs
│   │   └── code_documentation_test.exs
│   └── continuous_integration/
│       ├── ci_integration_test.exs
│       ├── automated_analysis_test.exs
│       └── quality_gates_test.exs
│
└── utilities/                         # Test utilities and tools
    ├── generators/
    │   ├── ast_generators.ex
    │   ├── cpg_generators.ex
    │   ├── graph_generators.ex
    │   ├── project_generators.ex
    │   └── event_generators.ex
    ├── profiling/
    │   ├── memory_profiler.ex
    │   ├── performance_profiler.ex
    │   └── benchmark_runner.ex
    ├── validation/
    │   ├── data_validators.ex
    │   ├── structure_validators.ex
    │   └── contract_validators.ex
    ├── setup/
    │   ├── test_environment.ex
    │   ├── database_setup.ex
    │   ├── ai_setup.ex
    │   └── distributed_setup.ex
    └── cleanup/
        ├── test_cleanup.ex
        ├── data_cleanup.ex
        └── resource_cleanup.ex
```

## Test Execution Patterns

### By Test Type
```bash
# Unit tests (fast, isolated)
mix test test/unit/

# Integration tests (cross-component)
mix test test/integration/

# Functional tests (feature-level)
mix test test/functional/

# End-to-end tests (complete workflows)
mix test test/end_to_end/

# Performance tests
mix test test/performance/

# Property-based tests
mix test test/property/

# Contract tests
mix test test/contract/

# Smoke tests (quick health check)
mix test test/smoke/

# Scenario tests (real-world usage)
mix test test/scenarios/
```

### By Layer
```bash
# Foundation layer
mix test test/unit/foundation/ test/integration/foundation/ test/smoke/foundation_smoke_test.exs

# AST layer
mix test test/unit/ast/ test/integration/ast_* test/smoke/ast_smoke_test.exs

# Graph layer
mix test test/unit/graph/ test/integration/*graph* test/smoke/graph_smoke_test.exs

# CPG layer
mix test test/unit/cpg/ test/integration/*cpg* test/smoke/cpg_smoke_test.exs

# Analysis layer
mix test test/unit/analysis/ test/integration/*analysis* test/smoke/analysis_smoke_test.exs

# Query layer
mix test test/unit/query/ test/integration/*query* test/smoke/query_smoke_test.exs

# Capture layer
mix test test/unit/capture/ test/integration/*capture* test/smoke/capture_smoke_test.exs

# Intelligence layer
mix test test/unit/intelligence/ test/integration/*intelligence* test/smoke/intelligence_smoke_test.exs

# Debugger layer
mix test test/unit/debugger/ test/integration/*debugger* test/smoke/debugger_smoke_test.exs
```

### By Feature
```bash
# AI-related tests
mix test --include ai

# Phoenix-related tests
mix test --include phoenix

# Performance tests
mix test --include performance

# Slow tests
mix test --include slow

# External dependency tests
mix test --include external

# Distributed tests
mix test --include distributed
```

## Test Configuration

### Test Tags Usage
```elixir
# In test files, use appropriate tags:

@moduletag :unit                    # Unit tests
@moduletag :integration            # Integration tests
@moduletag :functional             # Functional tests
@moduletag :end_to_end             # E2E tests
@moduletag :performance            # Performance tests
@moduletag :property               # Property-based tests
@moduletag :contract               # Contract tests
@moduletag :smoke                  # Smoke tests
@moduletag :scenario               # Scenario tests

@moduletag :foundation             # Foundation layer
@moduletag :ast                    # AST layer
@moduletag :graph                  # Graph layer
@moduletag :cpg                    # CPG layer
@moduletag :analysis               # Analysis layer
@moduletag :query                  # Query layer
@moduletag :capture                # Capture layer
@moduletag :intelligence           # Intelligence layer
@moduletag :debugger               # Debugger layer

@moduletag :ai                     # Requires AI providers
@moduletag :phoenix                # Requires Phoenix
@moduletag :slow                   # Long-running tests
@moduletag :external               # External dependencies
@moduletag :distributed            # Multi-node tests
@moduletag :memory_intensive       # High memory usage
@moduletag :skip                   # Skip by default
```

## Benefits of This Structure

### 1. **Clear Test Organization**
- Tests grouped by type (unit, integration, etc.)
- Each layer has comprehensive coverage
- Easy to find specific test categories

### 2. **Flexible Test Execution**
- Run tests by type, layer, or feature
- Selective test execution for development
- Comprehensive CI/CD test suites

### 3. **Comprehensive Coverage**
- Unit tests for individual components
- Integration tests for component interaction
- Functional tests for complete features
- End-to-end tests for user workflows

### 4. **Performance Validation**
- Dedicated performance benchmarks
- Memory usage monitoring
- Scalability testing
- Regression detection

### 5. **Quality Assurance**
- Property-based testing for algorithm correctness
- Contract testing for API stability
- Smoke tests for quick health checks
- Real-world scenario validation

This structure ensures
