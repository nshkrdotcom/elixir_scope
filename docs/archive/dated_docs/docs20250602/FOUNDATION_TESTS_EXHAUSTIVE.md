Okay, here's an exhaustive list of one-line test descriptions for the ElixirScope Foundation Layer, complementing the existing tests and focusing on OTP behaviors, edge cases, and deeper module interactions:

**`test/contract/foundation_contracts_test.exs`**
(Testing that service modules correctly implement their declared contract behaviours)
- `ConfigServer` contract: `get/0` callback returns `{:ok, Config.t()} | {:error, Error.t()}`.
- `ConfigServer` contract: `get/1` callback with valid path returns `{:ok, value} | {:error, Error.t()}`.
- `ConfigServer` contract: `update/2` callback returns `:ok | {:error, Error.t()}`.
- `ConfigServer` contract: `validate/1` callback returns `:ok | {:error, Error.t()}`.
- `ConfigServer` contract: `updatable_paths/0` callback returns `[config_path()]`.
- `ConfigServer` contract: `reset/0` callback returns `:ok | {:error, Error.t()}`.
- `ConfigServer` contract: `available?/0` callback returns `boolean()`.
- `EventStore` (service) contract: `store/1` callback returns `{:ok, event_id()} | {:error, Error.t()}`.
- `EventStore` (service) contract: `store_batch/1` callback returns `{:ok, [event_id()]} | {:error, Error.t()}`.
- `EventStore` (service) contract: `get/1` callback returns `{:ok, Event.t()} | {:error, Error.t()}`.
- `EventStore` (service) contract: `query/1` callback returns `{:ok, [Event.t()]} | {:error, Error.t()}`.
- `EventStore` (service) contract: `get_by_correlation/1` callback returns `{:ok, [Event.t()]} | {:error, Error.t()}`.
- `EventStore` (service) contract: `prune_before/1` callback returns `{:ok, non_neg_integer()} | {:error, Error.t()}`.
- `EventStore` (service) contract: `stats/0` callback returns `{:ok, map()} | {:error, Error.t()}`.
- `EventStore` (service) contract: `available?/0` callback returns `boolean()`.
- `EventStore` (service) contract: `initialize/0` callback returns `:ok | {:error, Error.t()}`.
- `EventStore` (service) contract: `status/0` callback returns `{:ok, map()} | {:error, Error.t()}`.
- `TelemetryService` contract: `execute/3` callback returns `:ok`.
- `TelemetryService` contract: `measure/3` callback executes function and returns its result.
- `TelemetryService` contract: `emit_counter/2` callback returns `:ok`.
- `TelemetryService` contract: `emit_gauge/3` callback returns `:ok`.
- `TelemetryService` contract: `get_metrics/0` callback returns `{:ok, map()} | {:error, Error.t()}`.
- `TelemetryService` contract: `attach_handlers/1` callback returns `:ok | {:error, Error.t()}`.
- `TelemetryService` contract: `detach_handlers/1` callback returns `:ok`.
- `TelemetryService` contract: `available?/0` callback returns `boolean()`.
- `TelemetryService` contract: `initialize/0` callback returns `:ok | {:error, Error.t()}`.
- `TelemetryService` contract: `status/0` callback returns `{:ok, map()} | {:error, Error.t()}`.

**`test/integration/foundation/config_events_telemetry_test.exs`**
- Config reset operation emits a `:config_reset` event and `[:foundation, :config_resets]` telemetry.
- Invalid config update attempt still emits telemetry for the failed validation if applicable.
- EventStore pruning via `prune_before` emits `[:foundation, :event_store, :events_pruned]` telemetry.
- TelemetryService metrics for specific event patterns are correctly filtered by `Telemetry.get_metrics_for/1`.
- If EventStore is unavailable, ConfigServer `emit_config_event` logs warning and continues.
- If TelemetryService is unavailable, ConfigServer `emit_config_telemetry` logs warning and continues.
- If EventStore is unavailable, client `Events.store/1` returns appropriate service unavailable error.
- If TelemetryService is unavailable, client `Telemetry.emit_counter/2` fails silently or returns error.

**`test/integration/foundation/cross_service_integration_test.exs`**
- `ErrorContext` correctly captures and enhances an error originating in `ConfigLogic` and passed through `ConfigServer`.
- `EventStore` pruning based on `max_age_seconds` (from config) triggers telemetry.
- `TelemetryService` cleanup of old metrics uses `metric_retention_ms` from config.
- A complex operation using `ErrorContext.with_context` spanning `ConfigServer` and `EventStore` calls correctly aggregates breadcrumbs.
- GracefulDegradation for ConfigServer uses cached value, then pending update is retried and succeeds after ConfigServer restarts.
- GracefulDegradation for EventStore uses JSON fallback when primary serialization fails, then telemetry records the fallback.

**`test/integration/foundation/end_to_end_data_flow_test.exs`**
- `Foundation.initialize/1` with custom config options correctly initializes all services with those options.
- `Foundation.shutdown/0` correctly stops all services.
- `Foundation.health/0` reflects healthy status when all services are running.
- `Foundation.health/0` reflects degraded status if a core service is down.
- High volume of `Utils.generate_id` does not impact `TelemetryService` metric emission responsiveness.

**`test/integration/foundation/service_lifecycle_test.exs`**
- `Foundation.Supervisor` correctly restarts `ConfigServer` if it crashes during an update.
- `Foundation.Supervisor` correctly restarts `EventStore` if it crashes during a batch store.
- `Foundation.Supervisor` correctly restarts `TelemetryService` if it crashes during metric aggregation.
- When `ConfigServer` is restarted, subscribers are lost and need to re-subscribe.
- `EventStore` automatic pruning (via `Process.send_after`) continues after supervisor restart.
- `TelemetryService` automatic metric cleanup continues after supervisor restart.
- `Foundation.TaskSupervisor` can successfully run and complete a task that uses all three services.

**`test/smoke/foundation_smoke_test.exs`**
- `Foundation.version/0` returns a non-empty string.
- `ErrorContext.new/2` creates a valid context struct.
- `Error.new/1` for a known error type creates a valid error struct.
- `GracefulDegradation` (Config) `get_with_fallback/1` returns a value when server is up.
- `GracefulDegradation` (Events) `new_event_safe/2` returns a valid event.
- `Foundation.shutdown/0` executes without error.
- `Foundation.health/0` returns `{:ok, map}`.

**`test/unit/foundation/config_robustness_test.exs`**
(Assuming this primarily tests the client `Config` module and `GracefulDegradation`)
- `Config.get_with_default/2` uses default if path leads to nil in live config.
- `Config.safe_update/2` returns `:config_update_forbidden` for non-updatable path.
- `GracefulDegradation.initialize_fallback_system/0` is idempotent.
- `GracefulDegradation.retry_pending_updates/0` correctly applies a cached pending update.
- `GracefulDegradation.retry_pending_updates/0` removes update from cache after successful retry.
- `GracefulDegradation.get_default_config/0` returns a structurally valid `Config.t` map.
- `Config.subscribe/0` correctly registers caller with `ConfigServer`.
- `Config.unsubscribe/0` correctly removes caller from `ConfigServer` subscribers.

**`test/unit/foundation/config_test.exs` (client API)**
- `Config.initialize/1` with specific opts results in ConfigServer having those opts.
- `Config.status/0` returns error when ConfigServer is not running.
- `Config.available?/0` returns false when ConfigServer GenServer is not registered.
- `Config.get_with_default/2` with ConfigServer down still returns the default value.
- `Config.safe_update/2` returns error immediately for non-updatable path without calling ConfigServer.

**`test/unit/foundation/services/config_server_test.exs`**
- `ConfigServer.init/1` fails and stops if `ConfigLogic.build_config` returns an error.
- `ConfigServer.init/1` logs successful initialization.
- `ConfigServer.handle_call({:get_config_path, valid_path_to_nil_value}, ...)` returns `{:ok, nil}`.
- `ConfigServer.handle_call({:update_config, ...})` when `ConfigLogic.update_config` errors, replies with error and state is unchanged.
- `ConfigServer.handle_call(:reset_config, ...)` updates state to `ConfigLogic.reset_config()`.
- `ConfigServer.handle_call(:reset_config, ...)` notifies subscribers with `{:config_reset, new_config}`.
- `ConfigServer.handle_call(:reset_config, ...)` emits `config_reset` event and telemetry.
- `ConfigServer.handle_call(:get_metrics, ...)` returns a map including `:current_time`.
- `ConfigServer.handle_info({:DOWN, ref, :process, pid, reason}, state)` removes `pid` from `state.subscribers`.
- `ConfigServer.emit_config_event` correctly uses `ElixirScope.Foundation.Events.new_event/2`.
- `ConfigServer.emit_config_telemetry` uses correct event names for `TelemetryService`.
- `ConfigServer.create_service_error/1` creates an Error.t with specified severity and category.

**`test/unit/foundation/logic/config_logic_test.exs`**
- `ConfigLogic.merge_env_config/2` correctly deep-merges nested map values.
- `ConfigLogic.merge_env_config/2` handles env_config value that is not a map for a map key in config.
- `ConfigLogic.build_config/1` uses `Config.new()` as base.
- `ConfigLogic.reset_config/0` always returns a fresh `Config.new()`.
- `ConfigLogic.diff_configs/2` correctly shows `:old` and `:new` values for changed paths.
- `ConfigLogic.create_error/3` sets specified category, subcategory, and severity.

**`test/unit/foundation/validation/config_validator_test.exs`**
- `ConfigValidator.validate_ai_planning/1` checks `performance_target` is non-negative.
- `ConfigValidator.validate_ai_planning/1` checks `default_strategy` is one of the valid atoms.
- `ConfigValidator.validate_ring_buffer/1` checks `max_events` is positive.
- `ConfigValidator.validate_processing/1` checks `flush_interval` and `max_queue_size` are positive.
- `ConfigValidator.validate_vm_tracing/1` checks all fields are booleans.
- `ConfigValidator.validate_hot_storage/1` checks `max_age_seconds` and `prune_interval` are positive.
- `ConfigValidator.validate_warm_storage/1` checks `path` is binary if enabled.
- `ConfigValidator.validate_warm_storage/1` checks `compression` is valid atom if enabled.
- `ConfigValidator.create_error/3` correctly populates Error struct for config validation.

**`test/unit/foundation/types/config_test.exs`**
- `Config.new/1` with deep nested overrides correctly applies them.
- `Config.new/1` with empty keyword list returns default config.
- Access behaviour `pop/2` removes key and returns value and new struct.

**`test/unit/foundation/events_test.exs` (client API)**
- `Events.new_event/3` passes all options to `EventLogic.create_event/3`.
- `Events.debug_new_event/3` raises if `EventLogic.create_event` returns an error.
- `Events.serialize/1` delegates to `EventLogic.serialize_event/2`.
- `Events.deserialize/1` delegates to `EventLogic.deserialize_event/1`.
- `Events.serialized_size/1` delegates to `EventLogic.calculate_serialized_size/1`.
- `Events.function_entry/5` delegates to `EventLogic.create_function_entry/5`.
- `Events.function_exit/7` delegates to `EventLogic.create_function_exit/7`.
- `Events.state_change/5` delegates to `EventLogic.create_state_change/5`.
- `Events.query/1` converts keyword list query to map before calling `EventStore`.
- `Events.get_correlation_chain/1` delegates to `EventLogic.extract_correlation_chain/2` after getting events.
- `Events.get_time_range/2` calls query with correct time_range and order_by.
- `Events.get_recent/1` calls query with correct order_by and limit.

**`test/unit/foundation/services/event_store_test.exs`**
- `EventStore.init/1` schedules first pruning if `prune_interval` > 0.
- `EventStore.init/1` applies `max_events`, `max_age_seconds` from opts.
- `EventStore.handle_call({:store_event, ...})` when store is full, prunes oldest 10% before storing.
- `EventStore.handle_call({:store_batch, ...})` updates `state.metrics.events_stored` by batch size.
- `EventStore.handle_call({:query_events, query_with_unsupported_filter}, ...)` ignores unsupported filter.
- `EventStore.handle_call({:get_by_correlation, ...})` with `enable_correlation_index: false` still works (slower).
- `EventStore.handle_info(:prune_old_events, ...)` correctly calculates cutoff time.
- `EventStore.handle_info(:prune_old_events, ...)` re-schedules next pruning.
- `EventStore.do_prune_before/2` correctly updates `metrics.events_pruned` and `metrics.last_prune`.
- `EventStore.apply_query_sorting/2` handles `:event_id` and `:event_type` sorting.
- `EventStore.emit_telemetry_counter/2` handles `TelemetryService.available?() == false`.
- `EventStore.emit_telemetry_gauge/3` handles `TelemetryService.available?() == false`.
- `EventStore.extract_query_type/1` identifies all documented query types.

**`test/unit/foundation/logic/event_logic_test.exs`**
- `EventLogic.create_function_entry/5` populates `caller_module`, `caller_function`, `caller_line` from opts.
- `EventLogic.create_state_change/5` correctly calls `compute_state_diff/2`.
- `EventLogic.serialize_event/2` with `compression: false` option works.
- `EventLogic.calculate_serialized_size/1` reflects size difference with/without compression.
- `EventLogic.extract_correlation_chain/2` returns empty list if no matching events.
- `EventLogic.group_by_correlation/1` correctly sorts events within each group by timestamp.
- `EventLogic.transform_event_data/2` applies function only to `event.data`.
- `EventLogic.create_error/3` sets specified category, subcategory, and severity.

**`test/unit/foundation/validation/event_validator_test.exs`**
- `EventValidator.validate_required_fields/1` checks `node` and `pid` are present.
- `EventValidator.validate_field_types/1` checks `correlation_id` is binary if present.
- `EventValidator.validate_field_types/1` checks `parent_id` is positive integer if present.
- `EventValidator.validate_data_size/1` uses `:erlang.external_size/1` for estimation.
- `EventValidator.validate_event_type/1` covers all types listed in its definition.
- `EventValidator.create_error/3` correctly populates Error struct for event validation.

**`test/unit/foundation/types/event_test.exs`**
- `Event.new/1` handles keyword list with unknown keys gracefully (ignores them).
- The Event.t struct can be serialized and deserialized using `:erlang.term_to_binary/1`.

**`test/unit/foundation/telemetry_test.exs` (client API)**
- `Telemetry.execute/3` works when TelemetryService is not available (fails silently).
- `Telemetry.measure/3` works when TelemetryService is not available (function still runs).
- `Telemetry.time_function/3` constructs correct event_name and metadata.
- `Telemetry.emit_performance/3` constructs correct event_name for gauge.
- `Telemetry.emit_system_event/2` constructs correct event_name for counter.

**`test/unit/foundation/services/telemetry_service_test.exs`** (New Test File)
- `TelemetryService.init/1` with `enable_vm_metrics: false` does not attach VM metrics.
- `TelemetryService.init/1` schedules first metric cleanup.
- `TelemetryService.handle_cast({:execute_event, ...})` with new event_name creates new metric entry.
- `TelemetryService.handle_cast({:execute_event, name, %{counter: val}, _})` correctly increments existing counter.
- `TelemetryService.handle_cast({:execute_event, name, %{gauge: val}, _})` correctly updates existing gauge.
- `TelemetryService.handle_cast({:detach_handlers, non_existent_event_name}, ...)` handles gracefully.
- `TelemetryService.handle_call(:get_status, ...)` returns `metrics_count` and `handlers_count`.
- `TelemetryService.handle_call(:clear_metrics, ...)` empties `state.metrics`.
- `TelemetryService.handle_call({:attach_handlers, ...})` adds default handlers to `state.handlers`.
- `TelemetryService.handle_info(:cleanup_old_metrics, ...)` re-schedules next cleanup.
- `TelemetryService.handle_info(:cleanup_old_metrics, ...)` correctly removes metrics based on `metric_data.timestamp`.
- `TelemetryService.record_metric/4` correctly merges measurements for non-counter/gauge numeric values (average).
- `TelemetryService.execute_handlers/4` logs warning if a handler function fails.
- `TelemetryService.transform_to_nested_structure/1` handles single-level metric paths.
- `TelemetryService.transform_to_nested_structure/1` handles arbitrary deep nesting.
- `TelemetryService.put_nested_value/3` correctly creates nested maps.

**`test/unit/foundation/types/error_test.exs`**
- `Error.new/1` (from `elixir_scope/foundation/error.ex`) creates a struct with default fields from `error_definitions`.
- `Error.new/3` (from `elixir_scope/foundation/error.ex`) correctly uses message override.
- `Error.to_string/1` produces a readable string including code, type, message, context, severity.
- `Error.collect_error_metrics/1` emits telemetry with correct event name and metadata.
- All defined error types in `Error` module have corresponding entries in `@error_definitions`.

**`test/unit/foundation/utils_test.exs`**
- `Utils.generate_id/0` uses `System.unique_integer([:positive])` and `make_ref()`.
- `Utils.truncate_if_large/2` handling of unserializable data (returns data as-is).
- `Utils.deep_size/1` returns 0 for unserializable term if `:erlang.external_size` fails.
- `Utils.safe_inspect/1` handles uninspectable terms by returning `<uninspectable>`.
- `Utils.sanitize_string/1` handles empty string and string with only whitespace.
- `Utils.atomize_keys/1` handles list of maps correctly.
- `Utils.stringify_keys/1` handles list of maps correctly.
- `Utils.retry/2` if fun returns non-tuple, non-:ok success, it's treated as success.
- `Utils.format_duration/1` correctly handles 0 nanoseconds.
- `Utils.measure/1` uses `:microsecond` precision for timing.
- `Utils.measure_memory/1` calls `:erlang.garbage_collect()` before and after.
- `Utils.format_bytes/1` handles 0 bytes.
- `Utils.process_stats/0` returns all documented fields.
- `Utils.system_stats/0` returns all documented fields.
- `Utils.valid_positive_integer?/1` returns false for float.

**`test/unit/foundation/application_test.exs`** (New Test File for `elixir_scope/foundation/application.ex`)
- `Foundation.Application.start/2` defines ConfigServer as the first child.
- `Foundation.Application.start/2` defines EventStore as a child.
- `Foundation.Application.start/2` defines TelemetryService as a child.
- `Foundation.Application.start/2` defines Task.Supervisor as a child named `ElixirScope.Foundation.TaskSupervisor`.
- `Foundation.Application.start/2` uses `Supervisor.start_link/2` with `strategy: :one_for_one`.
- `Foundation.Application.start/2` uses `ElixirScope.Foundation.Supervisor` as the supervisor name.

**`test/unit/foundation/error_context_test.exs`** (New Test File)
- `ErrorContext.new/3` correctly sets `parent_context` from opts.
- `ErrorContext.child_context/4` correctly inherits `correlation_id` and merges metadata.
- `ErrorContext.add_breadcrumb/4` appends a correctly structured breadcrumb.
- `ErrorContext.add_metadata/2` merges new metadata with existing.
- `ErrorContext.with_context/2` puts context into process dictionary and deletes it on normal exit.
- `ErrorContext.with_context/2` puts context into process dictionary and deletes it on exception.
- `ErrorContext.enhance_error/2` for `{:error, reason}` creates a new Error.t with context.
- `ErrorContext.get_current_context/0` retrieves context from process dictionary.
- `ErrorContext.get_operation_duration/1` calculates duration correctly.
- `ErrorContext.add_context/3` for `{:ok, _}` returns the success tuple unchanged.
- `ErrorContext.add_context/3` (new version) enhances `Error.t` and merges `additional_info`.
- `ErrorContext.add_context/3` (new version) creates `Error.t` for raw `{:error, reason}`.
- `ErrorContext.create_exception_error/3` populates all context fields correctly.
- `ErrorContext.format_stacktrace/1` handles empty and nil stacktraces.

**`test/unit/foundation/graceful_degradation_test.exs`** (New Test File)
- Config GD: `initialize_fallback_system/0` creates ETS table `:foundation_config_fallback` if not present.
- Config GD: `get_with_fallback/1` when service available, caches value in ETS.
- Config GD: `update_with_fallback/2` when service available, clears cached value from ETS.
- Config GD: `update_with_fallback/2` when service unavailable, caches pending update in ETS with timestamp.
- Config GD: `retry_pending_updates/0` (internal task) logs failure if Config.update still fails.
- Events GD: `new_event_safe/3` when `Events.new_event` fails, returns minimal event map with `safe_data_conversion`.
- Events GD: `serialize_safe/1` for unserializable Event.t uses `fallback_serialize`.
- Events GD: `deserialize_safe/1` for un-Jason-decodable binary creates an error event.
- Events GD: `fallback_serialize/1` correctly cleans PIDs and DateTimes for JSON.
- Events GD: `reconstruct_event_from_map/1` handles missing fields from map.

**`test/unit/foundation_test.exs`** (Testing the `ElixirScope.Foundation` facade)
- `Foundation.initialize/1` calls `Config.initialize`, `Events.initialize`, `Telemetry.initialize` in order.
- `Foundation.initialize/1` propagates error if any underlying service initialization fails.
- `Foundation.status/0` aggregates status from `Config.status`, `Events.status`, `Telemetry.status`.
- `Foundation.status/0` propagates error if any underlying service status check fails.
- `Foundation.available?/0` correctly checks availability of all three services.
- `Foundation.version/0` retrieves version from `:elixir_scope` application spec.
- `Foundation.shutdown/0` calls `Supervisor.stop` on `ElixirScope.Foundation.Supervisor`.
- `Foundation.health/0` calls `determine_overall_health/1` with service statuses.
- `Foundation.determine_overall_health/1` (private) returns `:healthy` if all services running.
- `Foundation.determine_overall_health/1` (private) returns `:degraded` if any service not running.

**`test/performance/foundation/`**
- Measure `ConfigServer.update/2` latency with 0, 10, 100, 1000 subscribers.
- Measure `EventStore.store_batch/1` throughput for 1, 10, 100, 1000 events per batch.
- Measure `EventStore.query/1` latency for various filter complexities on 10k events.
- Measure `EventStore.get_by_correlation/1` latency on 10k events with 1000 unique correlation IDs.
- Measure `TelemetryService.emit_counter/2` and `emit_gauge/3` latency with 1, 100, 10000 unique metric paths.
- Measure `TelemetryService.get_metrics/0` latency with 1, 100, 10000 unique metric paths stored.
- Benchmark `Utils.deep_merge/2` vs `Map.merge/2` for various nesting depths and map sizes.
- Benchmark `ErrorContext.with_context/2` overhead for a simple function call.
- Benchmark `GracefulDegradation` (Config) `get_with_fallback/1` when service is up vs down (cache hit vs ETS).
- Benchmark `GracefulDegradation` (Events) `serialize_safe/1` for normal vs fallback path.

**`test/property/foundation/`**
- Property: `ConfigServer.get/1` after any sequence of valid/invalid `update/2` calls, returns a value consistent with the last successful update or default for that path.
- Property: `EventStore.query/1` for any valid query, if events are returned, they all match the query criteria.
- Property: `EventStore.prune_before(ts)` ensures no events with `timestamp < ts` remain.
- Property: For `TelemetryService`, the sum of all counter increments for a given path equals the final `count` for that path.
- Property: For `TelemetryService`, the last `gauge` value emitted for a path is the one reported.
- Property: `Utils.atomize_keys/1` followed by `Utils.stringify_keys/1` (or vice-versa) on a map results in a map with original values and appropriately typed keys.
- Property: `Error.new(type, msg, opts)` always produces an `Error.t` where `context` is a map and `recovery_actions` is a list of strings.
- Property: `ErrorContext.with_context/2` when the function raises, the returned `Error.t`'s context contains `:operation_context` matching the input context.
- Property: `GracefulDegradation` (Config) `get_with_fallback/1` always returns a value or `{:error, _}` and never crashes.
- Property: `GracefulDegradation` (Events) `serialize_safe/1` always returns a binary and never crashes.
- Property: `Foundation.Application` supervisor strategy correctly restarts a crashing child a limited number of times.
- Property: `Foundation.status/0` always returns `{:ok, map}` or `{:error, Error.t()}` and never crashes, even if services are in flux.
