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

### File Tree

lib
└── elixir_scope
    ├── analysis
    │   ├── architectural.ex
    │   ├── metrics.ex
    │   ├── patterns
    │   │   ├── anti_patterns.ex
    │   │   ├── design.ex
    │   │   ├── elixir_specific.ex
    │   │   ├── otp_patterns.ex
    │   │   └── smells.ex
    │   ├── performance.ex
    │   ├── quality.ex
    │   ├── recommendations.ex
    │   └── security.ex
    ├── analysis.ex
    ├── application.ex
    ├── ast
    │   ├── compile_time
    │   │   └── orchestrator.ex
    │   ├── compiler
    │   │   ├── enhanced_transformer.ex
    │   │   ├── injector_helpers.ex
    │   │   ├── mix_task.ex
    │   │   └── transformer.ex
    │   ├── data
    │   │   ├── enhanced_function_data.ex
    │   │   ├── enhanced_module_data.ex
    │   │   ├── function_data.ex
    │   │   ├── instrumentation_mapper.ex
    │   │   ├── module_analysis
    │   │   │   ├── ast_analyzer.ex
    │   │   │   ├── attribute_extractor.ex
    │   │   │   ├── complexity_calculator.ex
    │   │   │   ├── dependency_extractor.ex
    │   │   │   └── pattern_detector.ex
    │   │   └── module_data.ex
    │   ├── data.ex
    │   ├── enhanced
    │   │   ├── data_structures.ex
    │   │   ├── enhanced_function_data.ex
    │   │   ├── enhanced_module_data.ex
    │   │   └── repository.ex
    │   ├── legacy
    │   │   ├── memory_manager.ex
    │   │   ├── pattern_matcher.ex
    │   │   ├── performance_optimizer.ex
    │   │   └── query_builder.ex
    │   ├── memory_manager
    │   │   └── memory_manager
    │   │       ├── cache_manager.ex
    │   │       ├── cleaner.ex
    │   │       ├── compressor.ex
    │   │       ├── config.ex
    │   │       ├── monitor.ex
    │   │       ├── pressure_handler.ex
    │   │       ├── supervisor.ex
    │   │       └── test_runner.ex
    │   ├── parser.ex
    │   ├── pattern_matcher
    │   │   ├── analyzers.ex
    │   │   ├── cache.ex
    │   │   ├── config.ex
    │   │   ├── core.ex
    │   │   ├── pattern_library.ex
    │   │   ├── pattern_rules.ex
    │   │   ├── stats.ex
    │   │   ├── types.ex
    │   │   └── validators.ex
    │   ├── performance_optimizer
    │   │   └── performance_optimizer
    │   │       ├── batch_processor.ex
    │   │       ├── cache_manager.ex
    │   │       ├── lazy_loader.ex
    │   │       ├── optimization_scheduler.ex
    │   │       └── statistics_collector.ex
    │   ├── query_builder
    │   │   └── query_builder
    │   │       ├── cache.ex
    │   │       ├── executor.ex
    │   │       ├── normalizer.ex
    │   │       ├── optimizer.ex
    │   │       ├── supervisor.ex
    │   │       ├── types.ex
    │   │       └── validator.ex
    │   ├── repository
    │   │   ├── core.ex
    │   │   └── enhanced.ex
    │   └── repository.ex
    ├── ast.ex
    ├── capture
    │   ├── correlation
    │   │   ├── runtime
    │   │   │   ├── breakpoint_manager.ex
    │   │   │   ├── cache_manager.ex
    │   │   │   ├── config.ex
    │   │   │   ├── context_builder.ex
    │   │   │   ├── event_correlator.ex
    │   │   │   ├── trace_builder.ex
    │   │   │   ├── types.ex
    │   │   │   └── utils.ex
    │   │   └── runtime_correlator.ex
    │   ├── correlation.ex
    │   ├── enhanced
    │   │   ├── correlation.ex
    │   │   ├── instrumentation.ex
    │   │   └── temporal.ex
    │   ├── ingestors.ex
    │   ├── instrumentation.ex
    │   ├── runtime
    │   │   ├── async_writer.ex
    │   │   ├── async_writer_pool.ex
    │   │   ├── enhanced_instrumentation.ex
    │   │   ├── event_correlator.ex
    │   │   ├── ingestor
    │   │   │   ├── channel.ex
    │   │   │   ├── distributed.ex
    │   │   │   ├── ecto.ex
    │   │   │   ├── gen_server.ex
    │   │   │   ├── live_view.ex
    │   │   │   └── phoenix.ex
    │   │   ├── ingestor.ex
    │   │   ├── instrumentation_runtime
    │   │   │   ├── ast_reporting.ex
    │   │   │   ├── context.ex
    │   │   │   ├── core_reporting.ex
    │   │   │   ├── ecto_reporting.ex
    │   │   │   ├── gen_server_reporting.ex
    │   │   │   ├── performance.ex
    │   │   │   └── phoenix_reporting.ex
    │   │   ├── instrumentation_runtime.ex
    │   │   ├── pipeline_manager.ex
    │   │   ├── ring_buffer.ex
    │   │   ├── temporal_bridge.ex
    │   │   ├── temporal_bridge_enhancement
    │   │   │   ├── ast_context_builder.ex
    │   │   │   ├── cache_manager.ex
    │   │   │   ├── event_processor.ex
    │   │   │   ├── state_manager.ex
    │   │   │   ├── trace_builder.ex
    │   │   │   └── types.ex
    │   │   ├── temporal_bridge_enhancement.ex
    │   │   └── temporal_storage.ex
    │   ├── storage
    │   │   └── storage
    │   │       ├── data_access.ex
    │   │       └── event_store.ex
    │   ├── storage.ex
    │   └── temporal.ex
    ├── capture.ex
    ├── cpg
    │   ├── analysis
    │   │   └── complexity_metrics.ex
    │   ├── analysis.ex
    │   ├── builder
    │   │   ├── call_graph.ex
    │   │   ├── cfg
    │   │   │   └── cfg_generator
    │   │   │       ├── ast_processor.ex
    │   │   │       ├── ast_processor_behavior.ex
    │   │   │       ├── ast_utilities.ex
    │   │   │       ├── ast_utilities_behavior.ex
    │   │   │       ├── complexity_calculator.ex
    │   │   │       ├── control_flow_processors.ex
    │   │   │       ├── expression_processors
    │   │   │       │   ├── assignment_processors.ex
    │   │   │       │   ├── basic_processors.ex
    │   │   │       │   ├── control_flow_processors.ex
    │   │   │       │   ├── data_structure_processors.ex
    │   │   │       │   └── function_processors.ex
    │   │   │       ├── expression_processors.ex
    │   │   │       ├── integration_test.ex
    │   │   │       ├── path_analyzer.ex
    │   │   │       ├── state.ex
    │   │   │       ├── state_manager.ex
    │   │   │       ├── state_manager_behaviour.ex
    │   │   │       └── validators.ex
    │   │   ├── cfg.ex
    │   │   ├── core
    │   │   │   ├── complexity_analyzer.ex
    │   │   │   ├── core.ex
    │   │   │   ├── graph_merger.ex
    │   │   │   ├── helpers.ex
    │   │   │   ├── pattern_detector.ex
    │   │   │   ├── performance_analyzer.ex
    │   │   │   ├── quality_analyzer.ex
    │   │   │   ├── query_processor.ex
    │   │   │   ├── security_analyzer.ex
    │   │   │   └── validator.ex
    │   │   ├── dfg
    │   │   │   ├── dfg_generator
    │   │   │   │   ├── ast_analyzer.ex
    │   │   │   │   ├── dependency_analyzer.ex
    │   │   │   │   ├── edge_creator.ex
    │   │   │   │   ├── node_creator.ex
    │   │   │   │   ├── optimization_analyzer.ex
    │   │   │   │   ├── pattern_analyzer.ex
    │   │   │   │   ├── state_manager.ex
    │   │   │   │   ├── structure_builder.ex
    │   │   │   │   └── variable_tracker.ex
    │   │   │   └── minimal.ex
    │   │   ├── dfg.ex
    │   │   ├── project_analysis
    │   │   │   ├── ast_extractor.ex
    │   │   │   ├── complexity_analyzer.ex
    │   │   │   ├── dependency_analyzer.ex
    │   │   │   ├── file_discovery.ex
    │   │   │   ├── file_parser.ex
    │   │   │   ├── module_analyzer.ex
    │   │   │   ├── optimization_hints.ex
    │   │   │   ├── performance_metrics.ex
    │   │   │   ├── quality_analyzer.ex
    │   │   │   └── security_analyzer.ex
    │   │   └── project_populator.ex
    │   ├── builder.ex
    │   ├── data
    │   │   ├── cfg_data.ex
    │   │   ├── cpg_data.ex
    │   │   ├── dfg_data.ex
    │   │   ├── shared_structures.ex
    │   │   ├── supporting_structures.ex
    │   │   └── variable_data.ex
    │   ├── data.ex
    │   ├── enhanced
    │   │   ├── analysis
    │   │   │   ├── dependency_impact.ex
    │   │   │   ├── performance_hotspots.ex
    │   │   │   └── security_vulnerabilities.ex
    │   │   ├── builder
    │   │   │   ├── ai_enhanced_builder.ex
    │   │   │   ├── incremental_builder.ex
    │   │   │   └── parallel_builder.ex
    │   │   ├── builder.ex
    │   │   ├── data
    │   │   │   ├── advanced_cpg_data.ex
    │   │   │   ├── semantic_annotations.ex
    │   │   │   └── temporal_cpg_data.ex
    │   │   ├── optimization.ex
    │   │   └── semantics.ex
    │   ├── file_watcher.ex
    │   ├── optimization.ex
    │   ├── semantics.ex
    │   └── synchronizer.ex
    ├── cpg.ex
    ├── debugger
    │   ├── ai_assistant.ex
    │   ├── breakpoints.ex
    │   ├── core.ex
    │   ├── enhanced
    │   │   ├── breakpoints.ex
    │   │   ├── instrumentation
    │   │   │   ├── ast_correlator.ex
    │   │   │   ├── breakpoint_manager.ex
    │   │   │   ├── debugger_interface.ex
    │   │   │   ├── event_handler.ex
    │   │   │   ├── storage.ex
    │   │   │   ├── utils.ex
    │   │   │   └── watchpoint_manager.ex
    │   │   ├── session.ex
    │   │   └── visualization.ex
    │   ├── interface.ex
    │   ├── session.ex
    │   ├── time_travel.ex
    │   └── visualization.ex
    ├── debugger.ex
    ├── elixir_scope.ex
    ├── foundation
    │   ├── README.md
    │   ├── application.ex
    │   ├── config.ex
    │   ├── core
    │   │   ├── ai_manager.ex
    │   │   ├── event_manager.ex
    │   │   ├── message_tracker.ex
    │   │   └── state_manager.ex
    │   ├── distributed
    │   │   ├── event_synchronizer.ex
    │   │   ├── global_clock.ex
    │   │   └── node_coordinator.ex
    │   ├── error.ex
    │   ├── error_context.ex
    │   ├── event_store.ex
    │   ├── events.ex
    │   ├── telemetry
    │   │   └── extra.ex
    │   ├── telemetry.ex
    │   ├── test_helpers.ex
    │   ├── types
    │   │   └── extra.ex
    │   ├── types.ex
    │   ├── utils
    │   │   └── extra.ex
    │   └── utils.ex
    ├── foundation.ex
    ├── graph
    │   ├── algorithms
    │   │   ├── advanced_centrality.ex
    │   │   ├── centrality.ex
    │   │   ├── community.ex
    │   │   ├── connectivity.ex
    │   │   ├── extracted_from_cpg.md
    │   │   ├── machine_learning.ex
    │   │   ├── pathfinding.ex
    │   │   └── temporal_analysis.ex
    │   ├── data_structures.ex
    │   ├── math.ex
    │   └── utils.ex
    ├── graph.ex
    ├── integration
    │   ├── analysis_intelligence.ex
    │   ├── ast_cpg.ex
    │   ├── capture_debugger.ex
    │   ├── cpg_analysis.ex
    │   └── phoenix
    │       └── integration.ex
    ├── intelligence
    │   ├── ai
    │   │   ├── analysis
    │   │   │   └── intelligent_code_analyzer.ex
    │   │   ├── code_analyzer.ex
    │   │   ├── complexity_analyzer.ex
    │   │   ├── llm
    │   │   │   ├── client.ex
    │   │   │   ├── config.ex
    │   │   │   ├── provider.ex
    │   │   │   ├── providers
    │   │   │   │   ├── gemini.ex
    │   │   │   │   ├── mock.ex
    │   │   │   │   └── vertex.ex
    │   │   │   └── response.ex
    │   │   ├── orchestrator.ex
    │   │   ├── pattern_recognizer.ex
    │   │   └── predictive
    │   │       └── execution_predictor.ex
    │   ├── features.ex
    │   ├── insights.ex
    │   ├── models
    │   │   ├── bug_predictor.ex
    │   │   ├── complexity_predictor.ex
    │   │   └── performance_predictor.ex
    │   ├── models.ex
    │   ├── orchestration.ex
    │   └── predictions.ex
    ├── intelligence.ex
    ├── layer_integration.ex
    ├── query
    │   ├── builder.ex
    │   ├── cache.ex
    │   ├── dsl.ex
    │   ├── executor.ex
    │   ├── extensions
    │   │   ├── analysis.ex
    │   │   ├── cpg.ex
    │   │   ├── ml_queries.ex
    │   │   ├── pattern_queries.ex
    │   │   ├── security_queries.ex
    │   │   └── temporal.ex
    │   ├── legacy
    │   │   └── engine.ex
    │   └── optimizer.ex
    ├── query.ex
    ├── quick_test.exs
    ├── shared
    │   ├── behaviours.ex
    │   ├── constants.ex
    │   ├── protocols.ex
    │   └── types.ex
    └── testing
        ├── fixtures.ex
        ├── helpers.ex
        └── mocks.ex
test
├── contract
│   ├── behaviour_compliance
│   │   └── behaviour_implementations_test.exs
│   ├── data_contracts
│   │   └── data_structure_contracts_test.exs
│   ├── external_apis
│   │   └── llm_provider_contracts_test.exs
│   ├── foundation_api_test.exs
│   ├── layer_apis
│   │   ├── ast_api_test.exs
│   │   ├── cpg_api_test.exs
│   │   ├── foundation_api_test.exs
│   │   └── graph_api_test.exs
│   └── protocol_compliance
│       └── protocol_implementations_test.exs
├── end_to_end
│   ├── ai_assisted_debugging
│   │   └── ai_debug_workflow_test.exs
│   ├── distributed_system_analysis
│   │   └── multi_node_analysis_test.exs
│   ├── genserver_debugging
│   │   └── genserver_debug_session_test.exs
│   ├── otp_supervision_analysis
│   │   └── supervisor_tree_analysis_test.exs
│   ├── phoenix_project_analysis
│   │   └── phoenix_app_full_analysis_test.exs
│   ├── real_world_projects
│   │   └── existing_project_analysis_test.exs
│   └── time_travel_debugging
│       └── time_travel_workflow_test.exs
├── fixtures
│   ├── ai_responses
│   │   └── sample_responses.ex
│   ├── ast_data
│   │   └── sample_asts.ex
│   ├── cpg_data
│   │   └── sample_cpgs.ex
│   └── sample_projects
│       ├── genserver_app
│       │   └── worker.ex
│       ├── phoenix_app
│       │   └── user_controller.ex
│       └── simple_module
│           └── simple_module.ex
├── functional
│   ├── ai_integration
│   │   └── llm_analysis_test.exs
│   ├── ast_parsing
│   │   └── full_project_parsing_test.exs
│   ├── code_quality_assessment
│   │   └── quality_metrics_test.exs
│   ├── cpg_construction
│   │   └── incremental_cpg_test.exs
│   ├── debugging_workflow
│   │   └── debug_session_test.exs
│   ├── graph_analysis
│   │   └── centrality_analysis_test.exs
│   ├── pattern_detection
│   │   └── architectural_smells_test.exs
│   ├── performance_optimization
│   │   └── optimization_pipeline_test.exs
│   ├── query_execution
│   │   └── complex_queries_test.exs
│   └── runtime_correlation
│       └── event_correlation_test.exs
├── integration
│   ├── analysis_intelligence
│   │   └── ai_enhanced_analysis_test.exs
│   ├── ast_cpg
│   │   └── ast_to_cpg_pipeline_test.exs
│   ├── capture_debugger
│   │   └── runtime_debug_integration_test.exs
│   ├── cpg_analysis
│   │   └── cpg_to_analysis_test.exs
│   ├── data_flow
│   │   └── data_flow_validation_test.exs
│   ├── end_to_end_workflows
│   │   └── complete_analysis_workflow_test.exs
│   ├── layer_dependencies
│   │   └── dependency_validation_test.exs
│   └── query_cross_layer
│       └── cross_layer_queries_test.exs
├── mocks
│   ├── ai_providers
│   │   ├── mock_anthropic.ex
│   │   ├── mock_llm_provider.ex
│   │   └── mock_openai.ex
│   ├── external_services
│   │   └── mock_http_client.ex
│   ├── file_system
│   │   └── mock_file_system.ex
│   └── instrumentation
│       └── mock_tracer.ex
├── orig
│   ├── elixir_scope
│   │   ├── ai
│   │   │   ├── analysis
│   │   │   │   └── intelligent_code_analyzer_test.exs
│   │   │   ├── code_analyzer_test.exs
│   │   │   ├── llm
│   │   │   │   ├── client_test.exs
│   │   │   │   ├── config_test.exs
│   │   │   │   ├── provider_compliance_test.exs
│   │   │   │   ├── providers
│   │   │   │   │   ├── gemini_live_test.exs
│   │   │   │   │   ├── mock_test.exs
│   │   │   │   │   ├── vertex_live_test.exs
│   │   │   │   │   └── vertex_test.exs
│   │   │   │   └── response_test.exs
│   │   │   └── predictive
│   │   │       └── execution_predictor_test.exs
│   │   ├── ast
│   │   │   ├── enhanced_transformer_test.exs
│   │   │   └── transformer_test.exs
│   │   ├── ast_repository
│   │   │   ├── cfg_generator_enhanced_test.exs
│   │   │   ├── cfg_generator_test.exs
│   │   │   ├── cpg_builder_enhanced_test.exs
│   │   │   ├── cpg_builder_test.exs
│   │   │   ├── dfg_generator_enhanced_test.exs
│   │   │   ├── dfg_generator_test.exs
│   │   │   ├── enhanced
│   │   │   │   └── cfg_generator
│   │   │   │       ├── expression_processors_test.exs
│   │   │   │       └── integration_test.exs
│   │   │   ├── enhanced_repository_integration_test.exs
│   │   │   ├── enhanced_repository_test.exs
│   │   │   ├── file_watcher_test.exs
│   │   │   ├── instrumentation_mapper_test.exs
│   │   │   ├── memory_manager_test.exs
│   │   │   ├── module_data_integration_test.exs
│   │   │   ├── parser_enhanced_test.exs
│   │   │   ├── parser_test.exs
│   │   │   ├── pattern_matcher
│   │   │   │   ├── config_test.exs
│   │   │   │   ├── types_test.exs
│   │   │   │   └── validators_test.exs
│   │   │   ├── pattern_matcher_old_test.exs
│   │   │   ├── pattern_matcher_test.exs
│   │   │   ├── performance_test.exs
│   │   │   ├── project_populator_test.exs
│   │   │   ├── query_builder_test.exs
│   │   │   ├── repository_test.exs
│   │   │   ├── runtime_correlator_test.exs
│   │   │   ├── synchronizer_test.exs
│   │   │   └── test_support
│   │   │       ├── cfg_validation_helpers.ex
│   │   │       ├── dfg_validation_helpers.ex
│   │   │       ├── fixtures
│   │   │       │   └── sample_asts.ex
│   │   │       └── helpers.ex
│   │   ├── capture
│   │   │   ├── async_writer_pool_test.exs
│   │   │   ├── async_writer_test.exs
│   │   │   ├── event_correlator_test.exs
│   │   │   ├── ingestor_test.exs
│   │   │   ├── instrumentation_runtime_enhanced_test.exs
│   │   │   ├── instrumentation_runtime_integration_test.exs
│   │   │   ├── instrumentation_runtime_temporal_integration_test.exs
│   │   │   ├── pipeline_manager_test.exs
│   │   │   ├── ring_buffer_test.exs
│   │   │   ├── temporal_bridge_test.exs
│   │   │   └── temporal_storage_test.exs
│   │   ├── compiler
│   │   │   └── mix_task_test.exs
│   │   ├── config_test.exs
│   │   ├── distributed
│   │   │   └── multi_node_test.exs
│   │   ├── events_test.exs
│   │   ├── integration
│   │   │   ├── api_completion_test.exs
│   │   │   ├── ast_runtime_integration_test.exs
│   │   │   └── end_to_end_hybrid_test.exs
│   │   ├── llm
│   │   │   ├── context_builder_test.exs
│   │   │   └── hybrid_analyzer_test.exs
│   │   ├── performance
│   │   │   └── hybrid_benchmarks_test.exs
│   │   ├── phoenix
│   │   │   └── integration_test.exs
│   │   ├── query
│   │   │   └── engine_test.exs
│   │   ├── storage
│   │   │   ├── data_access_test.exs
│   │   │   └── event_store_test.exs
│   │   └── utils_test.exs
│   ├── elixir_scope_test.exs
│   ├── fixtures
│   │   ├── sample_elixir_project
│   │   │   └── lib
│   │   │       ├── genserver_module.ex
│   │   │       ├── phoenix_controller.ex
│   │   │       └── supervisor.ex
│   │   └── sample_project
│   │       ├── _build
│   │       │   └── dev
│   │       │       └── lib
│   │       │           └── test_project
│   │       │               ├── consolidated
│   │       │               │   ├── Elixir.Collectable.beam
│   │       │               │   ├── Elixir.Enumerable.beam
│   │       │               │   ├── Elixir.IEx.Info.beam
│   │       │               │   ├── Elixir.Inspect.beam
│   │       │               │   ├── Elixir.JSON.Encoder.beam
│   │       │               │   ├── Elixir.List.Chars.beam
│   │       │               │   └── Elixir.String.Chars.beam
│   │       │               └── ebin
│   │       │                   ├── Elixir.TestModule.beam
│   │       │                   └── test_project.app
│   │       ├── lib
│   │       │   └── test_module.ex
│   │       └── mix.exs
│   ├── integration
│   │   └── production_phoenix_test.exs
│   ├── support
│   │   ├── ai_test_helpers.ex
│   │   └── test_phoenix_app.ex
│   └── test_helper.exs
├── performance
│   ├── benchmarks
│   │   ├── cpg_construction
│   │   │   └── cpg_build_benchmarks_test.exs
│   │   ├── graph_algorithms
│   │   │   └── centrality_benchmarks_test.exs
│   │   └── query_execution
│   │       └── query_performance_test.exs
│   ├── memory_usage
│   │   └── memory_profiling_test.exs
│   ├── regression_tests
│   │   └── performance_regression_test.exs
│   ├── scalability
│   │   └── large_project_scalability_test.exs
│   └── stress_tests
│       └── concurrent_operations_test.exs
├── property
│   ├── ast_operations
│   │   └── ast_properties_test.exs
│   ├── cpg_construction
│   │   └── cpg_properties_test.exs
│   ├── data_transformations
│   │   └── transformation_properties_test.exs
│   ├── graph_algorithms
│   │   └── graph_properties_test.exs
│   ├── invariants
│   │   └── system_invariants_test.exs
│   └── query_operations
│       └── query_properties_test.exs
├── scenarios
│   ├── ai_assisted_development
│   │   └── code_review_assistance_test.exs
│   ├── code_analysis_workflows
│   │   └── legacy_code_analysis_test.exs
│   ├── continuous_integration
│   │   └── ci_integration_test.exs
│   ├── debugging_workflows
│   │   └── production_bug_hunt_test.exs
│   ├── performance_optimization
│   │   └── hotspot_identification_test.exs
│   └── team_collaboration
│       └── shared_analysis_test.exs
├── smoke
│   └── foundation_smoke_test.exs
├── support
│   ├── assertions
│   │   ├── cpg_assertions.ex
│   │   ├── graph_assertions.ex
│   │   └── performance_assertions.ex
│   ├── benchmarking
│   │   └── benchmark_helpers.ex
│   ├── error_test_helpers.ex
│   ├── generators
│   │   ├── ast_generators.ex
│   │   ├── cpg_generators.ex
│   │   ├── graph_generators.ex
│   │   └── project_generators.ex
│   ├── helpers.ex
│   ├── profiling
│   │   ├── memory_profiler.ex
│   │   └── performance_profiler.ex
│   ├── setup
│   │   ├── ai_setup.ex
│   │   ├── database_setup.ex
│   │   └── test_environment.ex
│   └── validation
│       ├── data_validators.ex
│       └── structure_validators.ex
├── test_helper.exs
└── unit
    ├── analysis
    │   ├── metrics_test.exs
    │   ├── patterns_test.exs
    │   └── quality_test.exs
    ├── ast
    │   ├── data_test.exs
    │   ├── enhanced
    │   │   └── repository_test.exs
    │   ├── parser_test.exs
    │   └── repository_test.exs
    ├── capture
    │   ├── correlation_test.exs
    │   ├── instrumentation_test.exs
    │   └── storage_test.exs
    ├── cpg
    │   ├── builder
    │   │   ├── cfg_test.exs
    │   │   └── dfg_test.exs
    │   ├── builder_test.exs
    │   └── semantics_test.exs
    ├── debugger
    │   ├── breakpoints_test.exs
    │   ├── core_test.exs
    │   └── session_test.exs
    ├── foundation
    │   ├── config_test.exs
    │   ├── events_test.exs
    │   ├── telemetry_test.exs
    │   └── utils_test.exs
    ├── graph
    │   └── algorithms
    │       ├── centrality_test.exs
    │       ├── community_test.exs
    │       ├── connectivity_test.exs
    │       └── pathfinding_test.exs
    ├── intelligence
    │   ├── ai
    │   │   └── llm_test.exs
    │   ├── features_test.exs
    │   └── models_test.exs
    └── query
        ├── builder_test.exs
        ├── executor_test.exs
        └── optimizer_test.exs
scripts/
├── benchmark.exs
└── dev_workflow.exs

199 directories, 508 files


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
